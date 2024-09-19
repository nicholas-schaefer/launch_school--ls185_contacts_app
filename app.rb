require 'sinatra'
require 'pg'
require 'pry'

require_relative 'database_persistence'

configure do
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do
  def full_name(first_name:"", last_name:"")
    first_name&.capitalize!
    last_name&.capitalize!
    [first_name, last_name].join(" ")
  end
end

before do
  @storage ||= DatabasePersistence.new(logger: logger)
  @app_name ||= "cat contacts"
  @pagination_item_limit = 3
  @request_errors ||= []
  @add_contact_form ||= {
    first_name: "John",
    last_name: "Wick",
    phone_number: "867-5309",
    email: "jwick@gmail.com",
    note: "no one messes with john wick!"
  }
  @newly_added_contact_id ||= ""
end

def query_select_all_results
  @storage.find_all_contacts
end

def query_select_one_result(contact_id)
  @storage.find_contact(contact_id)
end

def page_title_tag(title:"", delimiter:"-", app_name:@app_name)
  return app_name if title.empty?
  "#{app_name} #{delimiter} #{title}"
end


## Methods in spired by https://stackoverflow.com/a/47511286
def valid_uuid_format?(uuid)
  uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  return true if uuid_regex.match?(uuid.to_s.downcase)
  # log_and_raise_error("Given argument is not a valid UUID: '#{format_argument_output(uuid)}'")
end

#######################################
# Pages
#######################################

def load_contact_page
  halt 404 unless valid_uuid_format?(params['contact_id'])

  result = query_select_one_result(params['contact_id'])
  halt 404 unless result.ntuples == 1

  @contact = result.first
  @path_slug = params['contact_id']
  @path_info = request.path_info
  @edit_action = "#{@path_info}/edit"
  @delete_action = "#{@path_info}/delete"
  # @path_info = params['slug']
  @page_title_tag = page_title_tag(title:"contact")

  erb :contact, :layout => :layout
end

def load_all_contacts_page
  # @request_errors = ["too lazy", "to tired", "need to get good"]
  total_contacts_count = @storage.contacts_total_count
  total_pages = total_contacts_count/@pagination_item_limit + 1
  @pages = (1..total_pages).to_a

  pagination_requested = params['page'] || '1'
  halt 404 unless @storage.string_also_an_integer?(pagination_requested) #lazy, need error message rewrite, helper class?
  halt 404 unless @pages.any?(pagination_requested.to_i) #need different error, means page not in range

  @validated_pagination_int = pagination_requested.to_i
  pagination_offset = (@validated_pagination_int - 1)* @pagination_item_limit

  # @contacts = query_select_all_results
  @contacts = @storage.find_selected_contacts(limit: @pagination_item_limit, offset:pagination_offset)
  @path_info = request.path_info
  @page_title_tag = page_title_tag(title:"home")

  erb :index, :layout => :layout
end


#######################################
# Routes
#######################################

get '/' do
  redirect to('/contacts')
end

# Get All Contacts
get '/contacts' do
  load_all_contacts_page
end

# Add a new contact
post '/contacts' do
  # erb "<p>something happened!</p>"

  first_name =  params['first_name'].strip.downcase #for sorting, should also have db trigger
  last_name = params['last_name'].strip.downcase #see above, (too much work!)
  phone_number = params['phone_number'].strip
  email = params['email'].strip
  note = params['note'].strip
  begin
    res = @storage.add_contact(
            first_name: first_name,
            last_name: last_name,
            phone_number: phone_number,
            email: email,
            note: note)
  rescue StandardError => e
    # erb "<p>database rejected entry for some reason</p> <p>#{e.message}</p>"
    # @request_errors << e.message
    regex = /violates check constraint "need_a_name"/
    if !!(regex =~ e.message)
      @request_errors << "Both first name and last name cannot be empty"
    else
      @request_errors << "Unspecified problem - Are you sending post requests outside the form - don't!!!!!"
    end
    @add_contact_form = {
      first_name: first_name,
      last_name: last_name,
      phone_number: phone_number,
      email: email,
      note: note
    }
    load_all_contacts_page
  else
    @newly_added_contact_id = res.first["id"]
    load_all_contacts_page
  end
end

# Get contact details
get '/contacts/:contact_id' do
  load_contact_page
end

# Update contact details
post '/contacts/:contact_id' do
  load_contact_page
end

# Delete an existing contact
post '/contacts/:contact_id/delete' do
  load_all_contacts_page
end

# Refreshes after delete revert the url to the main contacts listing page
get '/contacts/:contact_id/delete' do
  redirect to('/contacts')
end

# When there's a 404 error this is what happens
not_found do
  erb :page_not_found, :layout => :layout
end



# Update an existing contact
# post '/contacts/:contact_id/edit' do
#   erb :contact, :layout => :layout
# end

# Refreshes after edit the url to the contacts page
# get '/contacts/:contact_id/edit' do
#   @path_slug = params['contact_id']
#   redirect to("/contacts/#{params['contact_id']}")
# end
