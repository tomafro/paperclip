module Paperclip
  # Handles thumbnailing images that are uploaded.
  class Thumbnail

    attr_accessor :file

    # Creates a Thumbnail object set to work on the +file+ given. It
    # will attempt to transform the image into one defined by +target_geometry+
    # which is a "WxH"-style string. +format+ will be inferred from the +file+
    # unless specified. Thumbnail creation will raise no errors unless
    # +whiny_thumbnails+ is true (which it is, by default.
    def initialize file, options
      @file             = file
      @options = options
      #       @target_geometry  = target_geometry && Geometry.parse(target_geometry)
      #       @current_geometry = file && Geometry.from_file(file)
      # 
      @current_format   = @file && File.extname(@file.path)
      @basename         = @file && File.basename(@file.path, @current_format)
      #       
      #       @format = format
    end

    def options
      @options
    end

    # Returns true if the +target_geometry+ is meant to crop.
    def crop?
      options[:dimensions][-1,1] == '#'
    end

    def extension
      options[:format]
    end
    
    def current_geometry
      @current_geometry ||= Geometry.from_file(file)
    end
    
    def whiny_thumbnails
      !(options[:whiny_thumbnails] == false)
    end
    
    def target_geometry
      @target_geometry ||= Geometry.parse(options[:dimensions])
    end

    # Performs the conversion of the +file+ into a thumbnail. Returns the Tempfile
    # that contains the new image.
    def make
      src = @file
      dst = Tempfile.new([@basename, extension.to_s].compact.join("."))
      dst.binmode

      command = <<-end_command
        #{ Paperclip.path_for_command('convert') }
        "#{ File.expand_path(src.path) }"
        #{ transformation_command }
        "#{ File.expand_path(dst.path) }"
      end_command
      
      success = system(command.gsub(/\s+/, " "))

      if success && $?.exitstatus != 0 && whiny_thumbnails
        raise PaperclipError, "There was an error processing this thumbnail"
      end

      dst
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = current_geometry.transformation_to(target_geometry, crop?)
      trans = "-scale \"#{scale}\""
      trans << " -crop \"#{crop}\" +repage" if crop
      trans
    end
  end

  # Due to how ImageMagick handles its image format conversion and how Tempfile
  # handles its naming scheme, it is necessary to override how Tempfile makes
  # its names so as to allow for file extensions. Idea taken from the comments
  # on this blog post:
  # http://marsorange.com/archives/of-mogrify-ruby-tempfile-dynamic-class-definitions
  class Tempfile < ::Tempfile
    # Replaces Tempfile's +make_tmpname+ with one that honors file extensions.
    def make_tmpname(basename, n)
      extension = File.extname(basename)
      sprintf("%s,%d,%d%s", File.basename(basename, extension), $$, n, extension)
    end
  end
end
