task :convert_textile_to_markdown_project => :environment do
  require 'tempfile'
  Project.all.each do |project|
    textile = project.description
     
    src = Tempfile.new('textile')
    src.write(textile)
    src.close
    dst = Tempfile.new('markdown')
    dst.close
    
    command = [
      "pandoc",
      "--no-wrap",
      "--smart",
      "-f",
      "textile",
      "-t",
      "markdown_github",
      src.path,
      "-o",
      dst.path,
#      "|",
#      "tr",
#      "-s",
#      "' '",
#      "' '",
#      ">",
#      dst.path
    ]
    system(*command) or raise "pandoc failed"
    
    dst.open
    markdown = dst.read
    
    # remove the \ pandoc puts before * and > at begining of lines
    markdown.gsub!(/^((\\[*>])+)/) { $1.gsub("\\", "") }
    
    # add a blank line before lists
    markdown.gsub!(/^([^*].*)\n\*/, "\\1\n\n*")
    
    project.update_attribute(:description, markdown)
  end
end
  
  
