class DataStringIo < StringIO
  attr_accessor :content_type, :original_filename

  def initialize filename, content_type, data
    super data

    self.original_filename = filename
    self.content_type = content_type
  end
end