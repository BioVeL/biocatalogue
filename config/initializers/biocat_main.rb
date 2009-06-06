# BioCatalogue: app/config/initializers/biocat_main.rb
#
# Copyright (c) 2008, University of Manchester, The European Bioinformatics 
# Institute (EMBL-EBI) and the University of Southampton.
# See license.txt for details

# NOTE: 
# all libraries within /lib/bio_catalogue will be loaded automatically by Rails (when accessed),
# as long as they follow the convention. E.g.: the module BioCatalogue::ActsAsHuman
# should be defined in the file /lib/bio_catalogue/acts_as_human.rb
#
# Some of these need to be preloaded...
require 'bio_catalogue/acts_as_service_versionified'
require 'bio_catalogue/has_submitter'

# Require additional libraries
require 'array'
require 'object'
require 'addressable/uri'
require 'system_timer'
require 'libxml'
require 'dnsruby'

# Never explicitly load the memcache-client library as we need to use 
# the specific one vendored in our codebase.
#require 'memcache'

# Change XML backend that Rails uses to a faster one
#XmlMini.backend = 'LibXML'   # Not working currently. TODO: set this up when implementing the XML REST API.

# Initialise the country codes library
CountryCodes

# Set up caches
BioCatalogue::CacheHelper.setup_caches

# Set up loggers to STDOUT if in script/console 
# (so now things like SQL queries etc are shown in the console instead of the development/production/etc logs).
if "irb" == $0
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActionController::Base.logger = Logger.new(STDOUT)
end

# Set global pagination per_page parameter in all models.
PAGE_ITEMS_SIZE = 10
class ActiveRecord::Base
  cattr_reader :per_page
  @@per_page = PAGE_ITEMS_SIZE
end

# The amount of time to cache the metadata counts data.
METADATA_COUNTS_DATA_CACHE_TIME = 60*60  # 60 minutes, in seconds.

BOT_IGNORE_LIST = "Googlebot",
                  "Slurp",
                  "msnbot",
                  "crawler",
                  "bot",
                  "heritrix",
                  "spider",
                  "Nutch"


# List of annotation attributes that are considered "known" or important in the system
KNOWN_ANNOTATION_ATTRIBUTES = [ "tag",
                                "description",
                                "name",
                                "example",
                                "documentation_url",
                                "rating.speed",
                                "rating.reliability",
                                "rating.ease-of-use",
                                "rating.documentation" ].freeze


# ================================
# Configure the Annotations plugin
# --------------------------------

# Remember that all attribute names specified MUST be in lowercase

# Disabled this due to ontological term URIs as tags...
#Annotations::Config.attribute_names_for_values_to_be_downcased.concat([ "tag" ])

Annotations::Config.strip_text_rules.update({ "tag" => [ '"' ] })

Annotations::Config.limits_per_source = { "rating.speed" => [ 1, true ],
                                          "rating.reliability" => [ 1, true ],
                                          "rating.ease-of-use" => [ 1, true ],
                                          "rating.documentation" => [ 1, true ] }

Annotations::Config.attribute_names_to_allow_duplicates = [ "tag",
                                                            "rating.speed",
                                                            "rating.reliability",
                                                            "rating.ease-of-use",
                                                            "rating.documentation" ]

# ================================


# ================================
# Ratings categories configuration
# --------------------------------

# These take the form:
# { rating_annotation_attribute_name => [ visible_name, help_text ] }

# IMPORTANT: remember to update any Annotations plugin configuration settings above when adding to this.

SERVICE_RATINGS_CATEGORIES = { "rating.speed" => [ "Speed", "Rate how fast this service has been for you" ],
                               "rating.reliability" => [ "Reliability", "Rate how reliable this service has been for you" ],
                               "rating.ease-of-use" => [ "Ease of Use", "Rate how easy this service has been to use for you" ],
                               "rating.documentation" => [ "Documentation",  "Rate the level and usefulness of documentation you feel this service has" ] }.freeze

# ================================


# ====================================================
# Configure global settings for the Disqus integration
# ----------------------------------------------------

Disqus::defaults[:avatar_size] = 48
Disqus::defaults[:color] = "green"
Disqus::defaults[:default_tab] = "recent"
Disqus::defaults[:num_items] = 15

# ====================================================


# ==============================================================
# Configure the Delayed::Jobs plugin (for background processing)
# --------------------------------------------------------------

Delayed::Job.destroy_failed_jobs = false

# ==============================================================