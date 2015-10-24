require "rubygems"
# require "bundler/setup"
require "sinatra"
require "data_mapper"
require 'pony'

enable :sessions

set :bind, '0.0.0.0'

# configure :production do
  # Do not serve static assets with sinatra in production
#  set :static, false
# end

# configure :development do
  # max_age is in seconds 
#  set :static_cache_control, [:public, :max_age => 3600]
# end

#contants
SITE_TITLE = "Beasley Accounting &amp; Tax,&nbsp;LLC"
EMAIL = ENV["BEASLEYACCOUNTING_EMAIL"]
FROM_EMAIL = ENV["BEASLEYACCOUNTING_FROM_EMAIL"]

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/#{ENV['BEASLEYACCOUNTING_DB']}")

class Email
  include DataMapper::Resource
  property :id, Serial
  property :from_email, Text, :length => 255, :required => true
  property :subject, Text, :length => 255, :required => true
  property :message, Text, :length => 2048, :required => true
  property :created_at, DateTime
  property :updated_at, DateTime
end

DataMapper.finalize.auto_upgrade!

#helper and alias for escaping HTML
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

#the main route to display the home view
get '/' do
  @title = 'Home'
  if not session[:notice].nil?
    @notice = session[:notice]
    session[:notice] = nil
  end
  
  if not session[:error].nil?
    @error = session[:error]
    session[:error] = nil
  end
  
  erb :home
end

post '/' do
  @title = 'Home'
  errors = {}
  
  #create a new Email object for setting param values  
  e = Email.new
  
  #phone input field is the honeypot: only process if honeypot is empty (simple anti-bot technique)
  if params[:phone].empty?
    
    #need a valid email address
    if params[:from_email].empty? or (params[:from_email] =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/).nil?
      errors[:from_email] = 'Your email is required so we can reply to your inquiry.'
    else
      e.from_email = h(params[:from_email])
    end

    if params[:subject].empty?
      errors[:subject] = 'A subject is required so we can sort incoming emails.'
    else
      e.subject = h(params[:subject])
    end
  
    if params[:message].empty?
       errors[:message] = 'A message is required so that we have more details to help you.'
    else
      e.message = h(params[:message])
    end
    e.created_at = Time.now
    e.updated_at = Time.now
    
    #only try to save to DB if there were no errors
    if errors.empty?
      if e.save
        #mail that sucka!
        Pony.mail :to => EMAIL,
                  :from => FROM_EMAIL,
                  :subject => "An email from beasleyaccounting.com",
                  :body => "A message from: " << h(params[:from_email]) << " \nSubject: " << h(params[:subject]) << " \nMessage: " << h(params[:message])
        session[:notice] = 'Message sent! Thank you for contacting us.'
        redirect to('/')
      else
        session[:error] = 'Something went wrong when submitting the form. How about giving us a call?'
        redirect to('/')
      end #e.save
    end #errors.empty?
  end #params[:phone].empty?
  
  #pass the errors hash back to the view
  @errors = errors
  
  #render home view
  erb :home
end

#always go to home route if nothing is found
not_found do
   redirect to('/')
end