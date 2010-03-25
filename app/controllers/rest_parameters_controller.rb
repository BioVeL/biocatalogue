# BioCatalogue: app/controllers/rest_parameters_controller.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

class RestParametersController < ApplicationController
  
  before_filter :disable_action, :only => [ :index, :show, :edit, :localise_globalise_parameter ]
  before_filter :disable_action_for_api

  before_filter :login_required
  
  before_filter :find_rest_method, :only => [ :new_popup, :add_new_parameters ]
  before_filter :find_rest_parameter, :except => [ :new_popup, :add_new_parameters ]
  
  before_filter :authorise, :except => [ :new_popup, :add_new_parameters ]

  def update_default_value  
    # sanitize user input to make it have characters that are only fit for URIs
    params[:new_value].chomp!
    params[:new_value].strip!
    default_value = CGI::escape(params[:new_value])
    
    do_not_proceed = default_value.blank? || params[:old_value]==default_value

    unless do_not_proceed
      @rest_parameter.default_value = default_value
      @rest_parameter.save!
    end
    
    respond_to do |format|
      if do_not_proceed
        flash[:error] = "An error occured while trying to update the default value for parameter <b>#{@rest_parameter.name}</b>"
      else
        flash[:notice] = "The default value for parameter <b>#{@rest_parameter.name}</b> has been updated"
      end
      format.html { redirect_to get_redirect_url }
      format.xml  { head :ok }
    end
  end
  
  def edit_default_value_popup
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
  
  def remove_default_value
    @rest_parameter.default_value = nil
    @rest_parameter.save!
    
    respond_to do |format|
      flash[:notice] = "The default value has been deleted from parameter <b>#{@rest_parameter.name}</b>"

      format.html { redirect_to get_redirect_url }
      format.xml  { head :ok }
    end
  end
  
  def inline_add_default_value
    # sanitize user input to make it have characters that are only fit for URIs
    params[:default_value].chomp!
    params[:default_value].strip!
    default_value = CGI::escape(params[:default_value])

    unless default_value.blank?
      @rest_parameter.default_value = default_value
      @rest_parameter.save!
    end
    
    respond_to do |format|
      format.html { render :partial => "rest_parameters/#{params[:partial]}", 
                           :locals => { :parameter => @rest_parameter,
                                        :rest_method_id => params[:rest_method_id]} }
      format.js { render :partial => "rest_parameters/#{params[:partial]}", 
                         :locals => { :parameter => @rest_parameter, 
                                      :rest_method_id => params[:rest_method_id] } } 
    end
  end
  
  def update_constraint
    do_not_proceed = params[:new_constraint].blank? || 
                     params[:old_constraint]==params[:new_constraint] || 
                     @rest_parameter.constrained_options.include?(params[:new_constraint])

    unless do_not_proceed
      @rest_parameter.constrained_options.delete(params[:old_constraint])
      @rest_parameter.constrained_options << params[:new_constraint]
      @rest_parameter.save!
    end
    
    respond_to do |format|
      if do_not_proceed
        flash[:error] = "An error occured while trying to update constraint for parameter <b>#{@rest_parameter.name}</b>"
      else
        flash[:notice] = "Constraint for parameter <b>#{@rest_parameter.name}</b> has been updated"
      end
      format.html { redirect_to get_redirect_url }
      format.xml  { head :ok }
    end
  end

  def edit_constraint_popup
    @old_constraint = params[:constraint]
    
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
  
  def remove_constraint
    @rest_parameter.constrained_options.delete(params[:constraint])
    @rest_parameter.save!
    
    respond_to do |format|
      flash[:notice] = "Constraint has been deleted from parameter <b>#{@rest_parameter.name}</b>"

      format.html { redirect_to get_redirect_url }
      format.xml  { head :ok }
    end
  end
  
  def inline_add_constraints
    do_not_proceed = params[:constraint].blank? || 
                     @rest_parameter.constrained_options.include?(params[:constraint])
    
    unless do_not_proceed
      @rest_parameter.constrained_options << params[:constraint]
      @rest_parameter.save!
    end
    
    respond_to do |format|
      format.html { render :partial => "rest_parameters/#{params[:partial]}", 
                           :locals => { :parameter => @rest_parameter,
                                        :rest_method_id => params[:rest_method_id]} }
      format.js { render :partial => "rest_parameters/#{params[:partial]}", 
                         :locals => { :parameter => @rest_parameter, 
                                      :rest_method_id => params[:rest_method_id] } } 
    end
  end

  def new_popup    
    respond_to do |format|
      format.js { render :layout => false }
    end
  end

  def add_new_parameters    
    resource = @rest_method.rest_resource # for redirection
    service = resource.rest_service.service # for redirection
    
    results = @rest_method.add_parameters(params[:rest_parameters], current_user, :make_local => true)
    
    respond_to do |format|
      unless results[:created].blank?
        flash[:notice] ||= ""
        flash[:notice] += "The following parameters were successfully created:<br/>"
        results[:created].each { |e| 
          flash[:notice] += (e==results[:created][0] ? "#{e}" : " , #{e}")
        }
        flash[:notice] += "<br/><br/>"
      end
      
      unless results[:updated].blank?
        flash[:notice] ||= ""
        flash[:notice] += "The following parameters already exist and have been updated:<br/>"
        results[:updated].each { |e| 
          flash[:notice] += (e==results[:updated][0] ? "#{e}" : " , #{e}")
        }
      end
      
      unless results[:error].blank?
        flash[:error] = "The following parameters could not be added:<br/>"
        results[:error].each { |e| 
          flash[:error] += (e==results[:error][0] ? "#{e}" : " , #{e}")
        }
      end
      
      format.html { redirect_to @rest_method }
    end
  end
  
  def localise_globalise_parameter
    url_to_redirect_to = get_redirect_url()

    param_name = @rest_parameter.name
  
    # destroy map
    destroy_method_param_map() # this is the map for the parameter being linked/unlinked

    is_not_used = RestMethodParameter.find(:all, :conditions => {:rest_parameter_id => @rest_parameter.id}).empty?
    @rest_parameter.destroy if is_not_used
    
    # make unique or generic
    associated_method = RestMethod.find(params[:rest_method_id])    
    if params[:make_local] # make the param unique to the method
      associated_method.add_parameters(param_name, current_user, :make_local => true)
    else # use an already existing param OR create one as needed
      associated_method.add_parameters(param_name, current_user)
    end

    respond_to do |format|
      if params[:make_local]
        success_msg = "Parameter <b>#{param_name}</b> now has a copy unique for endpoint <b>" + associated_method.display_endpoint + "</b>"
      else
        success_msg = "Parameter <b>#{param_name}</b> for endpoint <b>" + associated_method.display_endpoint + "</b> is now global"
      end

      format.html { redirect_to url_to_redirect_to }
      format.xml  { head :ok }
    end
  end
  
  def make_optional_or_mandatory
    @rest_parameter.required = !@rest_parameter.required
    @rest_parameter.save!
    
    respond_to do |format|
      flash[:notice] = "Parameter <b>#{@rest_parameter.name}</b> is now " + (@rest_parameter.required ? 'mandatory':'optional')
      format.html { redirect_to get_redirect_url }
      format.xml  { head :ok }
    end
  end
  
  def destroy
    success_msg = "Parameter <b>#{@rest_parameter.name}</b> has been deleted"

    url_to_redirect_to = get_redirect_url()
    
    destroy_method_param_map()
    
    is_not_used = RestMethodParameter.find(:all, :conditions => {:rest_parameter_id => @rest_parameter.id}).empty?
    @rest_parameter.destroy if is_not_used
        
    respond_to do |format|
      flash[:notice] = success_msg
      format.html { redirect_to url_to_redirect_to }
      format.xml  { head :ok }
    end
  end
  
  
  # ========================================
  
  
  protected
  
  def authorise
    unless BioCatalogue::Auth.allow_user_to_curate_thing?(current_user, @rest_parameter, :rest_method => RestMethod.find(params[:rest_method_id]))
      error_to_back_or_home("You are not allowed to perform this action")
      return false
    end

    return true
  end


  # ========================================
  
  
  private
  
  def get_redirect_url()
    method_param_map = RestMethodParameter.find(:first, 
                                                :conditions => {:rest_parameter_id => @rest_parameter.id, 
                                                                :rest_method_id => params[:rest_method_id]})

    rest_method = RestMethod.find(params[:rest_method_id])

    return rest_method_url(rest_method)
  end
  
  def destroy_method_param_map() # USES params[:rest_method_id] and @rest_parameter.id
    method_param_map = RestMethodParameter.find(:first, 
                                                :conditions => {:rest_parameter_id => @rest_parameter.id, 
                                                                :rest_method_id => params[:rest_method_id]})
    method_param_map.destroy
  end
  
  def find_rest_parameter
    @rest_parameter = RestParameter.find(params[:id])
  end
  
  def find_rest_method
    @rest_method = RestMethod.find(params[:rest_method_id])
  end

end
