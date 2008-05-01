namespace :gloc do

  desc 'Sorts the keys in the string bundles'
  task :sort do
    dir = ENV['DIR'] || '{.,vendor/plugins/*}/lang'
    puts "Processing directory #{dir}"
    files = Dir.glob(File.join(dir,'*.{yaml,yml}'))
    puts 'No files found.' if files.empty?
    files.each {|file|
      puts "Sorting file: #{file}"
      header = []
      content = IO.readlines(file)
      content.each {|line| line.gsub!(/[\s\r\n\t]+$/,'')}
      content.delete_if {|line| line==''}
      tmp= []
      content.each {|x| tmp << x unless tmp.include?(x)}
      content= tmp
      header << content.shift if !content.empty? && content[0] =~ /^file_charset:/
      content.sort!
      filebak = "#{file}.bak"
      File.rename file, filebak
      File.open(file, 'w') {|fout| fout << header.join("\n") << content.join("\n") << "\n"}
      File.delete filebak
      # Report duplicates
      count= {}
      content.map {|x| x.gsub(/:.+$/, '') }.each {|x| count[x] ||= 0; count[x] += 1}
      count.delete_if {|k,v|v==1}
      puts count.keys.sort.map{|x|"  WARNING: Duplicate key '#{x}' (#{count[x]} occurances)"}.join("\n") unless count.empty?
    }
  end

  desc 'Compares the keys in different language string bundles'
  task :cmpkeys do
    dir= ENV['DIR'] || 'lang'
    files= Dir.glob(File.join(dir,'*.{yaml,yml}'))
    puts 'No files found.' if files.empty?
    # Get data
    keys= {}
    langs= []
    files.each {|file|
      lang= File.basename(File.basename(file,'.yml'),'.yaml')
      langs << lang
      content= IO.readlines(file)
      content.delete_if{|l| l.gsub!(%r{^\s+|\s+$},''); l==''}
      content.map{|l| %r{^([^ :]+):} =~ l ? $1 : l}.each {|k|
        keys[k] ||= {}
        keys[k][lang]= true
      }
      puts "Loaded #{file} (#{content.size})"
    }
    total_string_count= keys.size
    # Remove keys where all match
    keys.delete_if {|k,v| v.size == langs.size}
    # Display results
    langs.sort!
    x= '+' + langs.map{|l| '-' + '-'*l.length + '-+' }.join('')
    puts x
    puts '+' + langs.map{|l| ' ' + l + ' +'}.join('')
    puts x
    keys.keys.sort.each {|k|
      v= keys[k]
      puts '| ' + langs.map{|l| (v[l] ? '*' : ' ') + ' '*l.length}.join('| ') + '| ' + k
    }
    puts x
    langs.each {|l|
      c= 0
      keys.each_pair{|k,v| c += 1 unless v[l] }
      puts "Bundle :#{l} is missing #{c} strings of #{total_string_count}"
    }
  end
  
end