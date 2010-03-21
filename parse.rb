bill_name = ARGV[0]
pdf_file = ARGV[1]
output_file = ARGV[2]

unless bill_name
  raise "must specify the Bill name (including [HL] or [Lords])"
end

unless pdf_file
  raise "must specify a pdf file to process"
end

unless output_file
  raise "must specify an output file name"
end

if pdf_file[0..3] == "http"
  `curl -O #{pdf_file}`
  parts = pdf_file.split("/")
  pdf_file = parts.last
end

unless File.exists?(pdf_file)
  raise "pdf file not found"
end

#escape square brackets in the Bill name
esc_bill_name = bill_name.gsub("[", "\\[")
esc_bill_name = esc_bill_name.gsub("]", "\\]")
esc_bill_name = esc_bill_name.gsub(")", "\\(")
esc_bill_name = esc_bill_name.gsub(")", "\\)")

#run pdftotext over the pdf file
`pdftotext -layout #{pdf_file} _temp.txt`

output = []

RH_PAGENUM_FORMAT = Regexp.new "\\s*#{esc_bill_name}\\s\\s+(\\d+|i+)$"
LH_PAGENUM_FORMAT = Regexp.new "\\s*(\\d+|i+)\\s\\s+#{esc_bill_name}$"


enacted_line = ''

#examine each line in the temp file
File.open("_temp.txt").each do |line|
  add_line = true
  
  #suppress non-content lines
  case line
    #footer
    when /(HL )*Bill \d+\s*\d+\/\d+/
      add_line = false
    #page number righthand page
    when RH_PAGENUM_FORMAT
      add_line = false
    #page number lefthand page
    when LH_PAGENUM_FORMAT
      add_line = false
    #barcode placeholder
  when /xxxbarxxx/
    add_line = false
  end
      
  if add_line
    #strip out the line numbers
    line.gsub!(/\s\s+\d+$/, "")
    
    #normalize start of line spacing
    if line =~ /(?:\s*)\d+(\s\s+)[\(A-Z]/
      line.gsub!($1, "\t\t")
    end
    
    #normalize title spacing
    if line.strip == bill_name
      line = "                     #{bill_name}"
    end
    
    #normalize Schedule contents layout
    if line =~ /(?:\s*)Schedule \d+(\s+--\s+)[A-Z]/
      line.gsub!($1, " -- ")
    end
    if line =~ /(?:\s*)Part \d+(\s+--\s+)[A-Z]/
      line.gsub!($1, " -- ")
    end
    
    #handle the BE IT ENACTED bug
    if line =~ /\s*(B\s+)by the Queen's most Excellent Majesty, by and with the advice and/
      line.gsub!($1, " #{$1.gsub('B', ' ')}")
      enacted_line = line
      line = ""
    end
    if line =~ /\s*(E IT ENACTED)/
      line.gsub!($1, "BE IT ENACTED")
    end
    
    if line =~ /Short title and chapter\s\s+Extent of repeal/
      line = "Short title                                   Extent of repeal"
    end
    
    if line.strip =~ /(.*)\s\s+Act\s+(\d\d\d\d)\s+Section(.*)/
      line = "#{$1} Act #{$2}           Section#{$3}"
      if line =~ /(.*)(Act\s\d\d\d\d\s+Section.*)/
        line = "#{$1.rstrip} #{$2}"
      end
    end
    
    if line.strip =~ /(.*)\s\s+Act\s+(\d\d\d\d)\s+In section(.*)/
      line = "#{$1} Act #{$2}           In section#{$3}"
      if line =~ /(.*)(Act\s\d\d\d\d\s+In section.*)/
        line = "#{$1.rstrip} #{$2}"
      end
    end
    
    if line.strip =~ /(\(c\.\ \d+\))\s+([a-zA-Z].*)/
      line = "#{$1}                               #{$2}"
    end
    
    if line =~ /\s*\"*\([a-z](\)\s*)[\"a-z]/
      line.gsub!($1, ")  ")
    end
    if line =~ /\s*\"*\([0-9]+(\)\s*)[\"a-zA-Z]/
      line.gsub!($1, ")\t")
    end
    if line =~ /\s*\"*\([0-9]+[A-Z](\)\s*)[\"a-zA-Z]/
      line.gsub!($1, ")\t")
    end
    if line =~ /\s*\"*\([ivx]+(\)\s*)[\"a-zA-Z]/
      line.gsub!($1, ")\t")
    end
    if line =~ /\s*\"*\([ivx]+[a-z](\)\s*)[\"a-zA-Z]/
      line.gsub!($1, ")\t")
    end
    
    #do output
    unless line.strip.empty?
      output << line.strip
      if line.strip == bill_name
        output << ""
      end
      if line =~ /\s*(BE IT ENACTED)/
        output << enacted_line
      end
    end
  end
end

output << ""

puts output.length

File.open(output_file, 'w') { |f| f.write(output.join("\n")) }
File.delete("_temp.txt")