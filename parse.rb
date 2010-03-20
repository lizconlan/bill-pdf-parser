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
bill_name = bill_name.gsub("[", "\\[")
bill_name = bill_name.gsub("]", "\\]")
bill_name = bill_name.gsub(")", "\\(")
bill_name = bill_name.gsub(")", "\\)")

#run pdftotext over the pdf file
`pdftotext -layout #{pdf_file} _temp.txt`

output = []

RH_PAGENUM_FORMAT = Regexp.new "\\s*#{bill_name}\\s\\s+(\\d+|i+)$"
LH_PAGENUM_FORMAT = Regexp.new "\\s*(\\d+|i+)\\s\\s+#{bill_name}$"

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
    
    output << line.strip
  end
end

puts output.length

File.open(output_file, 'w') { |f| f.write(output.join("\n")) }
File.delete("_temp.txt")