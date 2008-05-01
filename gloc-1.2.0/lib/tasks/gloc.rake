namespace :gloc do
  desc 'Updates language files based on em.yml content'
  task :update do
    dir = ENV['DIR'] || './lang'
    
    en_strings = {}
    en_file = File.open(File.join(dir,'en.yml'), 'r')
    en_file.each_line {|line| en_strings[$1] = $2 if line =~ %r{^([\w_]+):\s(.+)$} }
    en_file.close
    
    files = Dir.glob(File.join(dir,'*.{yaml,yml}'))
    files.each do |file|
      puts "Updating file #{file}"
      keys = IO.readlines(file).collect {|line| $1 if line =~ %r{^([\w_]+):\s(.+)$} }.compact
      lang = File.open(file, 'a')
      en_strings.each do |key, str|
        next if keys.include?(key)
        puts "added: #{key}" 
        lang << "#{key}: #{str}\n"
      end
      lang.close
    end
  end
end
