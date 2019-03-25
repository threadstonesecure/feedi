class Feed < ApplicationRecord
  include W3CValidators

  # relations
  has_many :entries, dependent: :destroy
  
  # callbacks
  after_create :async_import
  
  # class methods
  def self.parse(url: )
    Feedjira::Feed.parse(RestClient.get(url).body)
  rescue URI::InvalidURIError => e
    Rails.logger.error(e)
    nil
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error(e)
    nil
  end 

  def self.add(url: )
    feed = parse(url: url)
    
    return false unless feed

    find_or_create_by(url: url) do |f|
      f.title = feed.title.strip
      f.description = feed.description.strip
      f.image = feed.image
    end
  end

  def self.validate(url: )
    FeedValidator.new.validate_uri(url)
  end

  # instance methods
  def import!
    fetch_entries.map do |entry|
      Entry.add(feed_id: self.id, entry: entry)
    end
  end

  def enrich!
    self.entries.where(enriched_at: nil).map do |entry|
      entry.enrich
      entry
    end
  end

  def async_import
    ImportWorker.perform_async(self.id)
  end

  private

  def fetch_entries
    self.class.parse(url: self.url).entries rescue []
  end
end
