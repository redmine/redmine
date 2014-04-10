task :convert_textile_to_markdown_wiki => :environment do
  require 'tempfile'
  WikiContent.all.each do |wiki|
    ([wiki] + wiki.versions).each do |version|
      textile = version.text
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
      ]
      system(*command) or raise "pandoc failed"

      dst.open
      markdown = dst.read

      # remove the \ pandoc puts before * and > at begining of lines
      markdown.gsub!(/^((\\[*>])+)/) { $1.gsub("\\", "") }

      # add a blank line before lists
      markdown.gsub!(/^([^*].*)\n\*/, "\\1\n\n*")

      version.update_attribute(:text, markdown)
    end
  end
end
