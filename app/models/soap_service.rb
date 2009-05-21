# BioCatalogue: app/models/soap_service.rb
#
# Copyright (c) 2008, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

class SoapService < ActiveRecord::Base
  acts_as_trashable
  
  acts_as_service_versionified
  
  acts_as_annotatable
  
  belongs_to :wsdl_file,
             :foreign_key => "wsdl_file_id",
             :class_name => "ContentBlob",
             :validate => true,
             :readonly => true,
             :dependent => :destroy
  
  has_many :soap_operations, 
           :dependent => :destroy,
           :include => [ :soap_inputs, :soap_outputs ]
  
  has_many :url_monitors, 
           :as => :parent,
           :dependent => :destroy
  
  # This is to protect some fields that should
  # only get their data from the WSDL doc.
  attr_protected :name, 
                 :description, 
                 :wsdl_file, 
                 :documentation_url
  
  validates_presence_of :name

  validates_associated :soap_operations
  
  validates_url_format_of :wsdl_location,
                          :allow_nil => false,
                          :message => 'is not valid'
   
  if ENABLE_SEARCH
    acts_as_solr(:fields => [ :name, :description, :documentation_url, :wsdl_location, :service_type_name ] )
  end
  
  if USE_EVENT_LOG
    acts_as_activity_logged(:models => { :referenced => { :model => :service_version } })
  end
  
  # ======================================
  # Class level method stubs reimplemented
  # from acts_as_service_versionified
  # --------------------------------------
  
  def self.check_duplicate(wsdl_location, endpoint)
    obj = SoapService.find(:first, :conditions => { :wsdl_location => wsdl_location }) #||
          # commenting the ||  on 10-03-2009
          # ================================
          #  Some wsdls share endpoints though not exposing the same interface.
          #  which makes them appear as duplicates of each other
          # e.g       http://www.cbs.dtu.dk/ws/MaxAlign/MaxAlign_1_1_ws0.wsdl
          #     and   http://www.cbs.dtu.dk/ws/SignalP/SignalP_3_1_ws0.wsdl 
          #ServiceDeployment.find(:first, :conditions => { :endpoint => endpoint })
          
    return (obj.nil? ? nil : obj.service)
  end
  
  # ======================================
  
  
  # =========================================
  # Instance level method stubs reimplemented
  # from acts_as_service_versionified
  # -----------------------------------------
  
  def service_type_name
    "SOAP"
  end
  
  # Note: 'name' fields are not considered "metadata", as these are standard and compulsory.
  def total_db_metadata_fields_count
    count = 0
    
    count += 1 unless self.description.blank?
    count += 1 unless self.documentation_url.blank?
    
    self.soap_operations.each do |op|
      count += 1 unless op.description.blank?
      count += 1 unless op.parameter_order.blank?
      
      op.soap_inputs.each do |input|
        count += 1 unless input.description.blank?
        count += 1 unless input.computational_type.blank?
      end
      
      op.soap_outputs.each do |output|
        count += 1 unless output.description.blank?
        count += 1 unless output.computational_type.blank?
      end
    end
    
    return count
  end
  
  # This method returns a count of all the annotations for this SoapService and its child operations/inputs/outputs.
  def total_annotations_count(source_type)
    count = 0
    
    count += self.count_annotations_by(source_type)
    
    self.soap_operations.each do |op|
      count += op.count_annotations_by(source_type)
      
      op.soap_inputs.each do |input|
        count += input.count_annotations_by(source_type)
      end
      
      op.soap_outputs.each do |output|
        count += output.count_annotations_by(source_type)
      end
    end
    
    return count
  end
  
  # =========================================


  # Populates (but does not save) this soap service with all the relevant data and child soap objects
  # based on the data from the WSDL file.
  #
  # Returns an array with:
  # - success - whether the process of populating the soap service suceeded or not.
  # - data - the hash structure representing the soap service and it's underlying metadata from the WSDL.
  def populate
    success = true
    data = { }
    
    if self.wsdl_location.blank?
      errors.add_to_base("No WSDL Location set for this Soap Service.")
      success = false
    end
    
    if success
      service_info, err_msgs, wsdl_file_contents = BioCatalogue::WsdlParser.parse(self.wsdl_location)
      
      unless err_msgs.empty?
        errors.add_to_base("Error occurred whilst processing the WSDL file. Error(s): #{err_msgs.to_sentence}.")
        success = false
      end
      
      if success
        self.wsdl_file = ContentBlob.new(:data => wsdl_file_contents)
        
        self.name         = service_info['name']
        self.description  = service_info['description']
        
        self.build_soap_objects(service_info)
        
        data["endpoint"] = service_info["end_point"]
      end
    end
    
    return [ success, data ]
  end
  
  def submit_service(endpoint, actual_submitter, annotations_data)
    success = true
    
    begin
      transaction do
        self.save!
        self.perform_post_submit(endpoint, actual_submitter)
      end
    rescue Exception => ex
      #ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid
      logger.error("ERROR: failed to submit SOAP service - #{endpoint}. Exception:")
      logger.error(ex.message)
      logger.error(ex.backtrace.join("\n"))
      success = false
    end  
    
    if success
      begin
        self.process_annotations_data(annotations_data, actual_submitter)
      rescue Exception => ex
        logger.error("ERROR: failed to process annotations after SOAP service creation. SOAP service ID: #{self.id}. Exception:")
        logger.error(ex.message)
        logger.error(ex.backtrace.join("\n"))
      end
    end
    
    return success
  end
 
 
  def latest_wsdl_location_status
    monitor = UrlMonitor.find(:first, 
                              :conditions => ["parent_id= ? AND parent_type= ?", self.id, self.class.to_s ],
                              :order => "created_at DESC" )
                              
    if monitor.nil?
      return TestResult.new(:result => -1)
    end
    
    result = TestResult.find(:first,
                               :conditions => ["test_id= ? AND test_type= ?", monitor.id, monitor.class.to_s ],
                               :order => "created_at DESC" )
    return result || TestResult.new(:result => -1 )
    
  end
   
  protected
  
  # This builds the parts of the SOAP service 
  # (ie: it's operations and their inputs and outputs).
  # This can then be saved transactionally.
  def build_soap_objects(service_info)
    soap_ops_built = [ ]
    
    service_info["operations"].each do |op|
      
      op_attributes = { :name => op["name"],
                        :description => op["description"],
                        :parameter_order => op["parameter_order"],
                        :parent_port_type => op["parent_port_type"]}
      inputs = op["inputs"]
      outputs = op["outputs"]
      
      soap_operation = soap_operations.build(op_attributes)
      
      inputs.each do |input_attributes|
        soap_operation.soap_inputs.build(input_attributes)
      end
      
      outputs.each do |output_attributes|
        soap_operation.soap_outputs.build(output_attributes)
      end
      
      soap_ops_built << soap_operation
      
    end
    
    return soap_ops_built
  end
  
end
