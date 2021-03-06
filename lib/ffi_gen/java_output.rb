class FFIGen
  def generate_java
    writer = Writer.new "    ", " * ", "/**", " */"
    writer.puts "package #{@package};", "// Generated by ffi_gen. Please do not change this file by hand.", "import jnr.ffi.*;", "import jnr.ffi.util.*;", "import jnr.ffi.mapper.*;", "import jnr.ffi.annotations.*;", "import java.lang.annotation.*;", "", "public class #{@module_name} {"
    writer.indent do
      writer.puts "public static #{@module_name}Interface INSTANCE = #{@module_name}Interface.InstanceCreator.createInstance();"
      writer.puts "public static jnr.ffi.Runtime RUNTIME;"
      writer.puts "", *IO.readlines(File.join(File.dirname(__FILE__), "java_static.java")).map(&:rstrip), ""

      declarations.each do |declaration|
        if declaration.respond_to? :write_static_java
          declaration.write_static_java writer
        else
          declaration.write_java writer
        end
      end
      writer.puts ""

      writer.puts "public interface #{@module_name}Interface {"
      writer.indent do
        writer.puts "", *IO.readlines(File.join(File.dirname(__FILE__), "java_interface.java")).map(&:rstrip), ""
        writer.puts "static class InstanceCreator {"
        writer.indent do
          writer.puts "private static #{@module_name}Interface createInstance() {"
          writer.indent do
            #writer.puts "DefaultTypeMapper typeMapper = new DefaultTypeMapper();", "typeMapper.addFromNativeConverter(NativeEnum.class, new EnumConverter());", "typeMapper.addToNativeConverter(NativeEnum.class, new EnumConverter());", ""
            #writer.puts "Map<String, Object> options = new HashMap<String, Object>();", "options.put(Library.OPTION_FUNCTION_MAPPER, new NativeNameAnnotationFunctionMapper());", "options.put(Library.OPTION_TYPE_MAPPER, typeMapper);", ""
            #writer.puts "return (#{@module_name}Interface) Native.loadLibrary(\"#{@ffi_lib}\", #{@module_name}Interface.class, options);"
            writer.puts "#{@module_name}Interface lib = LibraryLoader.create(#{@module_name}Interface.class)"
            writer.puts "  .option(LibraryOption.FunctionMapper, new NativeNameAnnotationFunctionMapper())"
            writer.puts "  .load(\"#{@ffi_lib}\");"
            writer.puts "RUNTIME = jnr.ffi.Runtime.getRuntime(lib);"
            writer.puts "return lib;"
          end
          writer.puts "}"
        end
        writer.puts "}", ""
        declarations.each do |declaration|
          if declaration.is_a? FunctionOrCallback
            declaration.write_java writer
          end
        end
      end
      writer.puts "}"
    end
    writer.puts "}"
    writer.output
  end
  
  class Name
    JAVA_KEYWORDS = %w{abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for goto if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while}
    
    def to_java_downcase
      format :camelcase, :initial_downcase, JAVA_KEYWORDS
    end
    
    def to_java_classname
      format :camelcase, JAVA_KEYWORDS
    end
    
    def to_java_constant
      format :upcase, :underscores, JAVA_KEYWORDS
    end
  end
  
  class Type
    def java_description
      java_name
    end
  end
  
  class Enum
    def write_java(writer)
      return if @name.nil?
      shorten_names
      
      writer.comment do
        writer.write_description @description
        writer.puts "", "<em>This entry is only for documentation and no real method. The FFI::Enum can be accessed via #enum_type(:#{java_name}).</em>"
        writer.puts "", "=== Options:"
        @constants.each do |constant|
          writer.puts "#{constant[:name].to_java_constant} ::"
          writer.write_description constant[:comment], false, "  ", "  "
        end
        writer.puts "", "@method _enum_#{java_name}_", "@return [Symbol]", "@scope class"
      end
      
      writer.puts "public enum #{java_name} implements EnumMapper.IntegerEnum {"
      writer.indent do
        writer.write_array @constants, "," do |constant|
          "#{constant[:name].to_java_constant}(#{constant[:value]})"
        end
        writer.puts ";"
        
        writer.puts "", "private int nativeInt;", "", "private #{java_name}(int nativeInt) {", "    this.nativeInt = nativeInt;", "}", "", "@Override", "public int intValue() {", "    return nativeInt;", "}"
      end
      writer.puts "}", ""
    end
    
    def java_name
      @java_name ||= @name.to_java_classname
    end
    
    def java_jna_type
      java_name
    end

    def java_jnr_struct_type
      "Enum<#{java_jna_type}>"
    end
    
    def java_description
      "Symbol from _enum_#{java_name}_"
    end
  end
  
  class StructOrUnion
    def write_java(writer)
      writer.comment do
        writer.write_description @description
        unless @fields.empty?
          writer.puts "", "= Fields:"
          @fields.each do |field|
            writer.puts ":#{field[:name].to_java_downcase} ::"
            writer.write_description field[:comment], false, "  (#{field[:type].java_description}) ", "  "
          end
        end
      end
      
      writer.puts "public static final class #{java_name} extends #{@is_union ? 'Union' : (@fields.empty? ? 'Struct' : 'Struct')} {"
      writer.indent do
        @fields.each do |field|
          initValue = "new #{field[:type].java_jnr_struct_type}("
          if field[:type].is_a?(ByValueType)
            initValue = "inner(#{initValue}getRuntime())"
          elsif field[:type].is_a?(Enum)
            initValue = "new Enum<>(#{field[:type].java_jna_type}.class"
          elsif field[:type].is_a?(FunctionOrCallback)
            initValue = "function(#{field[:type].java_jna_type}.class"
          end
          writer.puts "public #{field[:type].java_jnr_struct_type} #{field[:name].to_java_downcase} = #{initValue});"
          if field[:type].is_a?(FunctionOrCallback)
            field[:type].write_java writer
          end
        end
        writer.puts "// hidden structure" if @fields.empty?
      end
      #writer.indent do
        #writer.puts "protected List<java.lang.String> getFieldOrder() {"
        #writer.indent do
        #  fs = @fields.map{|f| '"' + f[:name].raw + '"'}.join(", ")
        #  writer.puts "return Arrays.asList(new java.lang.String[] { #{fs} } );"
        #end
        #writer.puts "}"
      #end
      writer.indent do
        writer.puts "public #{java_name}(jnr.ffi.Runtime runtime) {"
        writer.puts "  super(runtime);"
        writer.puts "}"
      end
      writer.puts "}", ""
      
      @written = true
    end
    
    def java_name
      @java_name ||= @name.to_java_classname
    end
    
    def java_jna_type
      #@written ? java_name : "jnr.ffi.Pointer"
      java_name
    end

    def java_jnr_struct_type
      java_jna_type
    end
    
    def java_description
      @written ? java_name : "FFI::Pointer(*#{java_name})"
    end
  end
  
  class FunctionOrCallback
    def write_java(writer)
      if @is_callback
        writer.puts "public static interface #{java_jna_type.split('.').last} {"
        writer.indent do
          jna_signature = "#{@parameters.map{ |parameter| "#{parameter[:type].is_a?(StructOrUnion) ? 'jnr.ffi.Pointer' : parameter[:type].java_jna_type} #{parameter[:name].to_java_downcase}" }.join(', ')}"
          writer.puts "@Delegate"
          writer.puts "#{@return_type.java_jna_type} invoke(#{jna_signature});"
        end
        writer.puts "}"
        writer.puts "public void set#{java_jna_type.split('.').last}(#{java_jna_type.split('.').last} callback) {"
        writer.indent do
          writer.puts "#{@name.to_java_downcase}.set(callback);"
        end
        writer.puts "}", ""
        return
      end

      jna_signature = "#{@parameters.map{ |parameter| "#{parameter[:type].java_jna_type} #{parameter[:name].to_java_downcase}" }.join(', ')}"
      writer.puts "@NativeName(\"#{@name.raw}\")", "#{@return_type.java_jna_type} #{java_name}(#{jna_signature});", ""
    end
    
    def write_static_java(writer)
      return if @is_callback # must be in Library
      
      replace = {}
      parameters = []
      lp = nil
      @parameters.each do |p|
        if lp && lp[:type].is_a?(PointerType) && lp[:type].pointee_type.respond_to?(:clang_type) && lp[:type].pointee_type.clang_type == :u_char && p[:type].clang_type == :u_long
          n = lp[:name].to_java_downcase
          replace[n] = "bytesToPointer(#{n})"
          replace[p[:name].to_java_downcase] = "new NativeLong(#{n}.length)";
          d = lp.dup
          d[:type] = ArrayType.new(lp[:type].pointee_type, nil)
          parameters << d
          lp = nil
        else
          if lp
            parameters << lp
          end
          lp = p
        end
      end
      if lp
        parameters << lp
      end
      
      writer.comment do
        writer.write_description @function_description
        writer.puts "", "<em>This entry is only for documentation and no real method.</em>" if @is_callback
        writer.puts "", "@method #{@is_callback ? "_callback_#{java_name}_" : java_name}(#{parameters.map{ |parameter| parameter[:name].to_java_downcase }.join(', ')})"
        parameters.each do |parameter|
          writer.write_description parameter[:description], false, "@param [#{parameter[:type].java_description}] #{parameter[:name].to_java_downcase} ", "  "
        end
        writer.write_description @return_value_description, false, "@return [#{@return_type.java_description}] ", "  "
        writer.puts "@scope class"
      end
      
      args = @parameters.map{ |parameter|
        n = parameter[:name].to_java_downcase
        replace[n] || n
      }.join(', ')
      jna_signature = "#{parameters.map{ |parameter| "#{parameter[:type].java_jna_type} #{parameter[:name].to_java_downcase}" }.join(', ')}"
      writer.puts "public static #{@return_type.java_jna_type} #{java_name}(#{jna_signature}) {"
      writer.indent do
        call = "INSTANCE.#{java_name}(#{args});"
        if @return_type.respond_to? :clang_type and @return_type.clang_type == :void
          writer.puts call
        else
          writer.puts "return #{call}"
        end
      end
      writer.puts "}", ""
    end
    
    def java_name
      #n = (@is_callback ? (@generator.module_name + 'Interface.') : '') + @name.to_java_downcase
      #@java_name ||= n
      @java_name ||= @name.to_java_downcase
    end
    
    def java_jna_type
      @name.to_java_classname
    end

    def java_jnr_struct_type
      "Function<#{java_jna_type}>"
    end
    
    def java_description
      "Function(#{java_jna_type})"
    end
  end
  
  class Define
    def write_java(writer)
      parts = @value.map { |v|
        if v.is_a? Array
          case v[0]
          when :method then v[1].to_java_downcase
          when :constant then v[1].to_java_constant
          else raise ArgumentError
          end
        else
          v
        end
      }
      if @parameters
        # not implemented
      else
        writer.puts "public static int #{@name.to_java_constant} = #{parts.join};", ""
      end
    end
  end
  
  class PrimitiveType
    attr_accessor :clang_type

    def java_name
      case @clang_type
      when :void
        "nil"
      when :bool
        "Boolean"
      when :u_char, :u_short, :u_int, :u_long, :u_long_long, :char_s, :s_char, :short, :int, :long, :long_long
        "Integer"
      when :float, :double
        "Float"
      end
    end
    
    def java_jna_type
      case @clang_type
      when :void            then "void"
      when :bool            then "boolean"
      when :u_char          then "byte"
      when :u_short         then "short"
      when :u_int           then "int"
      when :u_long          then "long"
      when :u_long_long     then "long"
      when :char_s, :s_char then "byte"
      when :short           then "short"
      when :int             then "int"
      when :long            then "long"
      when :long_long       then "@LongLong long"
      when :float           then "float"
      when :double          then "double"
      end
    end

    def java_jnr_struct_type
      case @clang_type
      when :void            then "void"
      when :bool            then "Boolean"
      when :u_char          then "Unsigned8"
      when :u_short         then "Unsigned16"
      when :u_int           then "Unsigned32"
      when :u_long          then "UnsignedLong"
      when :u_long_long     then "UnsignedLong"
      when :char_s, :s_char then "Signed8"
      when :short           then "Signed16"
      when :int             then "Signed32"
      when :long            then "SignedLong"
      when :long_long       then "SignedLong"
      when :float           then "Float"
      when :double          then "Double"
      end
    end
  end

  class StringType
    def java_name
      "String"
    end
    
    def java_jna_type
      "String"
    end

    def java_jnr_struct_type
      "UTF8StringRef"
    end
  end
  
  class ByValueType
    def java_name
      @inner_type.java_name
    end
    
    def java_jna_type
      @inner_type.java_jna_type
    end

    def java_jnr_struct_type
      java_jna_type
    end
  end
  
  class PointerType
    def java_name
      @pointee_name.to_java_downcase
    end
    
    def java_jna_type
      "jnr.ffi.Pointer" 
    end

    def java_jnr_struct_type
      "Pointer"
    end
    
    def java_description
      "FFI::Pointer(#{'*' * @depth}#{@pointee_name ? @pointee_name.to_java_classname : ''})"
    end
  end
  
  class ArrayType
    def java_name
      "array"
    end
    
    def java_jna_type
      if @constant_size
        "#{@element_type.java_jna_type}[#{@constant_size}]"
      else
        "#{@element_type.java_jna_type}[]"
      end
    end

    def java_jnr_struct_type
      java_jna_type
    end
    
    def java_description
      "Array of #{@element_type.java_description}"
    end
  end
    
  class UnknownType
    def java_name
      "unknown"
    end

    def java_jna_type
      "byte"
    end

    def java_jnr_struct_type
      "Pointer"
    end
  end
end