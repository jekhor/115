#!/usr/bin/ruby
# encoding: utf-8

require 'rest-client'
require 'nokogiri'
require 'json'
require 'time'
require 'parallel'

module MojHorad
  HEADERS = {
    'Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Charset':'utf-8, iso-8859-1, utf-16, *;q=0.7',
    'Accept-Language':'ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4',
    'Connection':'keep-alive',
    'User-Agent':'Mozilla/5.0 (Linux; U; Android 4.0.4; ru-ru; Android SDK built for x86 Build/IMM76D) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30',
  }
  BASE_URL = 'http://115.xn--90ais/'

  class API115
    def initialize
      @base_url = BASE_URL
      @cookies = {}
    end

    # check main page to get cookies with session key
    def begin
      r = query(:get, '')
      doc = Nokogiri::HTML(r.body)

      item = doc.css('input[name=_token]').first
      @token = item['value']
    end

    def change_city(city_id)
      STDERR.puts "Changing city to #{city_id}"
      query(:post, "city/change/#{city_id}", {_token: @token, _fgp: "03f8a842c278bf61690e9579e591c63b"})
    end

    def login(user, password)
      STDERR.puts "Logging in"
      query_api(:post, "user/login", { email: user, password: password})
    end

    def getlist(start_date=nil, deep=false)
      STDERR.print "Fetching problem list..."
      now = Time.now
      start_date ||= Time.new(now.year, now.month, 1)
      r = query_api(:post, 'problem/getlist', {date: start_date.strftime('%Y-%m-%d')})
      list = JSON.parse(r.body)
      STDERR.puts " done."

      if deep and not list['items'].empty?
        STDERR.puts "Digging deep for #{list['items'].size} problems..."

        Parallel.each(list['items'].keys, progress: {title: 'Fetching details', output: STDERR}, in_threads: 20) do |key|
          id = key
          item = list['items'][id]

          begin
            p = self.problem(id.to_i)
            item['description'] = p[:description]
            item['answers'] = p[:answers]
          rescue => e
            STDERR.puts e.message
          end
        end
      end

      list
    end

    def getlist_geojson(start_date=nil, deep=false)
      list = getlist(start_date, deep)
      items = list['items']

      if items.kind_of? Array and items.empty?
        items = {}
      end

      features = []
      items.each_value do |item|
        f = {}
        f[:type] = 'Feature'
        f[:geometry] = {
          type: 'Point',
          coordinates: [item['lng'].to_f, item['lat'].to_f]
        }

        f[:properties] = item.select {|k, v| k != 'lng' and k != 'lat'}

        features << f
      end

      geojson = {
        type: 'FeatureCollection',
        features: features
      }

      JSON.pretty_generate(geojson)
    end

    def getMapData(problem_id)
      query_api(:post, "problem/getMapData/#{problem_id}", {_token: @token})
    end

    def problem(problem_id)
      p = {}
      r = query(:get, "problem/#{problem_id}")

      doc = Nokogiri::HTML(r.body)
      p[:status] = doc.at_css('.b-current-problem__status')['data-status']
      p[:description] = doc.at_css('.b-current-problem__middle p').text.strip
      p[:answers] = []
      doc.css('.b-user-problem__answer__main').each do |answer|
        rating_item = answer.at_css('.b-performance-evaluation-wrapper')
        rating = rating_item.nil? ? nil : rating_item['assessment'].to_i

        photos = []

        answer.css('.b-answer__main .b-answer__main__photo__wrapper .b-answer__main__photo .b-problem-itm__pic').each do |item|
          photos += item['data-before'].split('|')
        end
        photos.uniq!

        a = {
          author: answer.at_css('.b-answer__title').text.strip,
          text: answer.at_css('.b-answer__main__text__itm').text.strip,
          date: answer.at_css('.b-answer__main__text__publish__itm__date').text.strip,
        }
        a[:rating] = rating unless rating.nil?
        a[:photos] = photos unless photos.empty?
        p[:answers] << a
      end
      p
    end

    # filter
    # 'status': api.problem.filter.status,
    # 'organisation': api.problem.filter.organisation,
    # 'date_start': api.problem.filter.date_start,
    # 'date_stop': api.problem.filter.date_stop,
    # 'number':  api.problem.filter.number,
    # 'expired': api.problem.filter.expired,
    # 'only_my': api.problem.filter.only_my

    def problem_filter(in_archive=0, page=1, filter)
      query_api(:post, 'problem/getlist/user/filter', {
        in_archive: in_archive,
        page: page,
        filter: filter
      })
    end

    def query_api(method, path, body=nil)
      body = {} if body.nil?
      if body.kind_of? Hash
        body.merge!({_token: @token, _fgp: "03f8a842c278bf61690e9579e591c63b"})
      end
      query(method, 'api/' + path, body)
    end

    def query(method, path, body=nil)
      begin
        r = RestClient::Request.execute method: method,
          url: @base_url + path,
          headers: HEADERS,
          payload: body,
          cookies: @cookies,
          timeout: 120

        @cookies = r.cookies
      rescue RestClient::Exception => e
        @cookies = e.response.cookies if e.response and e.response.cookies
        raise e
      end
      r
    end

  end
end


if __FILE__ == $0

  require 'optparse'
  require 'ostruct'

  options = OpenStruct.new
  options.geojson = false
  options.deep = false
  options.city_id = nil

  subtext = <<HELP
Commands:
  getlist [--geojson] [--deep] [YYYY-mm]  fetch all problems for given month
  problem <problem id> [<problem id>...]  fetch details for given problems
  filter [options] <in_archive> <page> <filter expression> filter by critera

  Cities:
    1 Минск
    2 Витебск
    3 Кричев
    4 Солигорск
    5 Кореличи
    6 Берестовица
    7 Вороново
    8 Зельва
    9 Щучин
    10 Волковыск
    11 Сморгонь
    12 Ошмяны
    13 Слоним
    14 Жлобин
    15 Рогачев
    16 Дятлово
    17 Новогрудок
    18 Гомель
    19 Мосты
    20 Бобруйск
    21 Свислочь
    22 Лида
    23 Островец
    24 Гродно
    25 Ивье
    26 Кличев
    33 Костюковичи
    34 Слуцк
    35 Климовичи
    37 Краснополье
    38 Хотимск
HELP

  global = OptionParser.new do |opts|
    opts.banner = "Usage: 115.rb [options] command [args]"
    opts.separator("Options:")
    opts.on('--city ID', "Change city to ID") {|v| options.city_id = v}
    opts.on('-v', '--verbose', "Show network requests") {|v| options.verbose = v}

    opts.separator subtext
  end

  subcommands = {
    'getlist' => OptionParser.new do |opts|
      opts.banner = "Usage: getlist [YYYY-mm]"
      opts.on('--geojson', "Use geojson format for output") {|v| options.geojson = v}
      opts.on('--deep', "Fetch details for each problem") {|v| options.deep = v}
    end,

    'problem' => OptionParser.new do |opts|
      opts.banner = "Usage: problem <problem id> [<problem id>...]"
    end,

    'filter' => OptionParser.new do |opts|
      opts.banner = "Usage: filter --login LOGIN --password PASSWORD <in_archive> <page> <filter expression>\n" +
        "  filter expression is combination of variables: status, organisation, date_start, date_stop, number, expired, only_my\n" +
        "  example: date_start=2018-10-11 date_stop=2018-10-15 status=3,4,5"

      opts.on('--login LOGIN', "User email to login") {|v| options.login = v}
      opts.on('--password PASSWORD', "User password to login") {|v| options.password = v}
    end,
  }

  global.order!
  command = ARGV.shift
  exit if command.nil?

  subcommands[command].order! unless command.nil?

  RestClient.log = STDERR if options.verbose

  c = MojHorad::API115.new

  c.begin

  unless options.city_id.nil?
    STDERR.puts "Changing city to #{options.city_id}"
    c.change_city(options.city_id.to_i)
  end

  case command
  when 'getlist'
    date = nil

    if ARGV.size >= 1
      date = Time.strptime(ARGV[0], '%Y-%m')
      STDERR.puts "Start date: " + date.strftime('%Y-%m-%d')
    end

    if options.geojson
      puts c.getlist_geojson(date, options.deep)
    else
      puts JSON.pretty_generate c.getlist(date, options.deep)
    end

  when 'problem'
    problem_ids = ARGV.map {|a| a.to_i}
    problems = {}
    problem_ids.each do |p|
      problems[p] = c.problem(p)
    end

    puts JSON.pretty_generate problems

  when 'filter'
    in_archive = ARGV[0].to_i != 0
    ARGV.shift
    page = ARGV[0].to_i
    ARGV.shift

    filter = {}
    ARGV.each do |arg|
      k, v = arg.split('=', 2)
      if k == 'status'
        v = v.split(',')
      end
      filter[k] = v
    end

    STDERR.puts "in_archive: #{in_archive.to_s}"
    STDERR.puts "page: #{page}"
    STDERR.puts "filter: #{filter}"

    c.login(options.login, options.password)
    puts JSON.parse c.problem_filter(in_archive, page, filter)
  end

end
