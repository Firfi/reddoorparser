require 'rest_client'
require 'nokogiri'

class HomeController < ApplicationController
  def index
    @loc = RestClient.post 'https://signin.managebuilding.com/Manager/PublicPages/Login.aspx',
                           'ctl00$contentPlaceHolderBody$txtUserName=info@reddoorproperty.com&ctl00$contentPlaceHolderBody$txtPassword=reddoor123&__EVENTTARGET=ctl00$contentPlaceHolderBody$btnLogIn&__EVENTARGUMENT=' do |response|
      response.raw_headers['location'][0]
    end

    RestClient.get @loc do |response|
      @cookies = response.cookies
      response
    end

    listedUnitsUrl = 'https://reddoorprop.managebuilding.com/Manager/DataServices/Building.svc/GetListings?$orderby=Listing%20asc,Available,PropertyUnit,BedRooms&buildingIds=\'-1\'&$skip=0&$top=100&$inlinecount=allpages&$format=json'

    RestClient.get listedUnitsUrl, {:cookies => @cookies} do |response|
      @rentals_json = response.body
    end


    @properties = ActiveSupport::JSON.decode(@rentals_json)

    test_id = @properties['d']['results'][0]['UnitId']


    @description_page_url = "https://reddoorprop.managebuilding.com/Manager/Properties/ListingAddEdit.aspx?unitId=#{test_id}"


    @description_page = RestClient.get @description_page_url, {:cookies => @cookies} do |response|
      response.body
    end


    doc = Nokogiri.HTML(@description_page)

    @desc = doc.css('#_ctl7_txtDescription').first.content

    @form = {}


    doc.css('input').each do |input|

      @form[input['name']] = input['value']
      if input['name'] == '__VIEWSTATE'
        @form['__EVENTTARGET'] = '_ctl7$actionBar'
        @form['__EVENTARGUMENT'] = '1'
      end
    end

    doc.css('textarea').each do |textarea|
      @form[textarea['name']] = textarea.inner_text
    end

    doc.css('select').each do |select|
      option = select.css('option[selected]').first['value'] rescue ''
      @form[select['name']] = option
    end


    @form['_ctl7:txtDescription'] = @form['_ctl7:txtDescription'] + ' test'
    @new_form = {}
    @form.each { |k, v| @new_form[Rack::Utils.escape(k)] = Rack::Utils.escape(v) }

    @raw_form = @new_form.inject('') { |raw, (name, value)| "#{raw}#{name}=#{value}&" }
    @raw_form = @raw_form.chomp('&')


    @resp = RestClient.post @description_page_url, @raw_form, {:cookies => @cookies} do |response|
      response
    end


  end
end
