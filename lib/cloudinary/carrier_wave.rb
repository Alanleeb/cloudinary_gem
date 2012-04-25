# Copyright Cloudinary
require 'cloudinary/carrier_wave/process'
require 'cloudinary/carrier_wave/error'
require 'cloudinary/carrier_wave/remote'
require 'cloudinary/carrier_wave/preloaded'
require 'cloudinary/carrier_wave/storage'

module Cloudinary::CarrierWave
  
  def self.included(base)
    base.storage Cloudinary::CarrierWave::Storage
    base.extend ClassMethods
    base.send(:attr_accessor, :metadata)
    base.send(:attr_reader, :stored_version)
        
    override_in_versions(base, :blank?, :full_public_id)
  end  
  
  def retrieve_from_store!(identifier)
    if identifier.blank?
      @file = @stored_version = @stored_public_id = nil
      self.original_filename = nil
    else
      @file = CloudinaryFile.new(identifier, self)
      @public_id = @stored_public_id = @file.public_id
      @stored_version = @file.version
      self.original_filename = @file.filename
    end
  end  
           
  def url(*args)
    if args.first && !args.first.is_a?(Hash)
      super
    else
      return super if self.blank?
      options = args.extract_options!
      options = self.transformation.merge(options) if self.version_name.present?
      Cloudinary::Utils.cloudinary_url(self.full_public_id, {:format=>self.format}.merge(options))
    end
  end
      
  def full_public_id
    return nil if self.blank?
    return self.my_public_id if self.stored_version.blank?
    return "v#{self.stored_version}/#{self.my_public_id}"
  end    

  def filename
    return nil if self.blank?
    return [self.full_public_id, self.format].join(".")
  end
      
  # public_id to use for uploaded file. Can be overridden by caller. Random public_id will be used otherwise.  
  def public_id
    nil
  end
  
  # If the user overrode public_id, that should be used, even if it's different from current public_id in the database.
  # Otherwise, try to use public_id from the database.
  # Otherwise, generate a new random public_id
  def my_public_id
    @public_id ||= self.public_id 
    @public_id ||= @stored_public_id
    @public_id ||= Cloudinary::Utils.random_public_id
  end  

  def recreate_versions!
    # Do nothing
  end
  
  def cache_versions!(new_file=nil)
    # Do nothing
  end
  
  def process!(new_file=nil)
    # Do nothing
  end
  
  # Should removed files be removed from Cloudinary as well. Can be overridden.
  def delete_remote?
    true
  end
  
  class CloudinaryFile
    attr_reader :identifier, :public_id, :filename, :format, :version
    def initialize(identifier, uploader)
      @uploader = uploader
      @identifier = identifier
      if @identifier.include?("/")
        version, @filename = @identifier.split("/")
        @version = version[1..-1] # remove 'v' prefix
      else
        @filename = @identifier
        @version = nil 
      end
      @public_id, @format = Cloudinary::CarrierWave.split_format(@filename)      
    end
    
    def delete
      Cloudinary::Uploader.destroy(self.public_id) if @uploader.delete_remote?        
    end
  end

  def self.split_format(identifier)
    last_dot = identifier.rindex(".")
    return [public_id, nil] if last_dot.nil?
    public_id = identifier[0, last_dot]
    format = identifier[last_dot+1..-1]
    return [public_id, format]    
  end

  # For the given methods - versions should call the main uploader method
  def self.override_in_versions(base, *methods)
    methods.each do
      |method|
      base.send :define_method, method do
        return super() if self.version_name.blank?
        uploader = self.model.send(self.mounted_as)
        uploader.send(method)    
      end
    end    
  end
end
