# Generated by ffi-gen. Please do not change this file by hand.

require 'ffi'

module CEF
  extend FFI::Library
  ffi_lib 'cef'
  
  def self.attach_function(name, *_)
    begin; super; rescue FFI::NotFoundError => e
      (class << self; self; end).class_eval { define_method(name) { |*_| raise e } }
    end
  end
  
  # (Not documented)
  class ListValue < FFI::Struct
    layout :dummy, :char
  end
  
  # Structure representing a message. Can be used on any process and thread.
  # 
  # = Fields:
  # :base ::
  #   (unknown) Base structure.
  # :is_valid ::
  #   (FFI::Pointer(*)) Returns true (1) if this object is valid. Do not call any other functions
  #   if this function returns false (0).
  # :is_read_only ::
  #   (FFI::Pointer(*)) Returns true (1) if the values of this object are read-only. Some APIs may
  #   expose read-only objects.
  # :copy ::
  #   (FFI::Pointer(*)) Returns a writable copy of this object.
  # :get_name ::
  #   (FFI::Pointer(*)) The resulting string must be freed by calling cef_string_userfree_free().
  # :get_argument_list ::
  #   (FFI::Pointer(*)) Returns the list of arguments.
  class ProcessMessage < FFI::Struct
    layout :base, :char,
           :is_valid, :pointer,
           :is_read_only, :pointer,
           :copy, :pointer,
           :get_name, :pointer,
           :get_argument_list, :pointer
  end
  
  # Create a new cef_process_message_t object with the specified name.
  # 
  # @method process_message_create(name)
  # @param [FFI::Pointer(*String)] name 
  # @return [ProcessMessage] 
  # @scope class
  attach_function :process_message_create, :cef_process_message_create, [:pointer], ProcessMessage
  
end