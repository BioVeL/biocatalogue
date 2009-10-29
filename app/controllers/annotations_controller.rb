# BioCatalogue: app/controllers/annotations_controller.rb
#
# Copyright (c) 2009, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details.

#=====
# This extends the Annotations controller defined in the Annotations plugin.
#=====

require_dependency RAILS_ROOT + '/vendor/plugins/annotations/lib/app/controllers/annotations_controller'

class AnnotationsController < ApplicationController
  
  # Disable some of the actions provided in the controller in the plugin.
  before_filter :disable_action, :only => [ :index, :show, :edit ]
  
  before_filter :add_use_tab_cookie_to_session, :only => [ :create, :create_multiple, :update, :destroy ]
  
  def new_popup
    # @annotatable is set in a before filter from the controller in the plugin. 
    if @annotatable.nil?
      flash[:error] = "Could not begin annotation (the thing you want to annotate is not specified or is invalid). Please contact the BioCatalogue folks."
      respond_to do |format|
        format.js {
          render :update do |page|
            page.redirect_to root_url
          end
        }
      end
    else
      @annotation = Annotation.new
    
      # Populate from query string values provided in the URL (if provided)
      @annotation.annotatable_type = params[:annotatable_type]
      @annotation.annotatable_id = params[:annotatable_id]
      @annotation.attribute_name = params[:attribute_name]
      
      @multiple = !params[:multiple].nil? && (params[:multiple].downcase == "true")
      @separator = params[:separator].nil? ? '' : params[:separator]
  
      respond_to do |format|
        format.js { render :layout => false }
      end
    end
  end
  
  def edit_popup
    login_required
    
    # Call an available before filter method (it's in plugin's controller).
    # If this fails, it will throw an exception that ActionController will catch,
    # so we don't need to check the success of it.
    find_annotation
    
    respond_to do |format|
      format.js { render :layout => false }
    end
  end
  
  def create_inline
    login_required
    
    # Call an available before filter method (it's in plugin's controller).
    # If this fails, it will throw an exception that ActionController will catch,
    # so we don't need to check the success of it.
    find_annotatable
    
    # Set source as the current logged in user
    params[:annotation][:source_type] = current_user.class.name
    params[:annotation][:source_id] = current_user.id
    
    # Do we create multiple annotations or a single annotation?
    if params[:multiple]
      success, annotations, errors = Annotation.create_multiple(params[:annotation], params[:separator])
    else
      annotation = Annotation.new(params[:annotation])
      annotation.annotatable = @annotatable
      annotation.save!    # This will raise an exception if it fails
    end
    
    respond_to do |format|
      format.html { redirect_to @annotatable }
      format.js { render :partial => "annotations/#{params[:partial]}", :locals => { :annotatable => @annotatable } } 
    end
  end
  
  def download
    # Call an available before filter method (it's in plugin's controller).
    # If this fails, it will throw an exception that ActionController will catch,
    # so we don't need to check the success of it.
    find_annotation
    
    send_data(@annotation.value, :type => "text/plain", :disposition => 'inline')
  end
  
end