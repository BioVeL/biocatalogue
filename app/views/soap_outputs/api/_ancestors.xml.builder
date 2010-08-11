# BioCatalogue: app/views/soap_outputs/api/_ancestors.xml.builder
#
# Copyright (c) 2010, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# <ancestors>
parent_xml.ancestors do
  
  # <service>
  service = Service.find(soap_output.associated_service_id)
  parent_xml.service nil, 
    { :resourceName => display_name(service, false), :resourceType => "Service" },
    xlink_attributes(uri_for_object(service), :title => xlink_title("The parent Service that this SOAP Output - #{display_name(soap_output, false)} - belongs to"))
  
  # <soapService>
  soap_service = soap_output.soap_operation.soap_service
  parent_xml.soapService nil, 
    { :resourceName => display_name(soap_service, false), :resourceType => "SoapService" },
    xlink_attributes(uri_for_object(soap_service), :title => xlink_title("The parent SOAP Service that this SOAP Output - #{display_name(soap_output, false)} - belongs to"))
  
  # <soapOperation>
  parent_xml.soapOperation nil, 
    { :resourceName => display_name(soap_output.soap_operation, false), :resourceType => "SoapOperation" },
    xlink_attributes(uri_for_object(soap_output.soap_operation), :title => xlink_title("The parent SOAP Service that this SOAP Output - #{display_name(soap_output, false)} - belongs to"))
    
end