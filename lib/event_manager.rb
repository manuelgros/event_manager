require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(phonenumber)
  phonenumber = phonenumber.tr('^0-9', '')
  if phonenumber.size == 10 || (phonenumber.size == 11 && phonenumber[0] == 1)
    phonenumber[-10..].insert(3, ' ').insert(-5, ' ')
  else
    'XXX XXX XXXX'
  end
end

def legislators_by_zipcode(zipcode) # rubocop:disable Metrics/MethodLength
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, letter_template)
  Dir.mkdir('output') unless Dir.exist?('output') # rubocop:disable Lint/NonAtomicFileOperation

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts letter_template
  end
end

def find_peak_day(dates_and_time)
  find_largest_hash_key(dates_and_time.map {
    |date| Date::DAYNAMES[Time.strptime(date, '%D').wday]
  }.tally)
end

def find_largest_hash_key(hash)
  hash.key(hash.values.max)
end

def find_peak_time(dates_and_time)
  find_largest_hash_key(dates_and_time.map {
    |date| Time.strptime(date, '%D %R').hour
  }.tally)
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
dates_and_time = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phonenumber = clean_phonenumber(row[:homephone])
  dates_and_time << row[:regdate]

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  puts "#{id} #{name} #{phonenumber}"
end

puts "\nThe PEAK TIME for registration was around #{find_peak_time(dates_and_time)}:00"
puts "The BEST DAY for registration was #{find_peak_day(dates_and_time)}"
