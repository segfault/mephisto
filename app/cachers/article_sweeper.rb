class ArticleSweeper < ActionController::Caching::Sweeper
  observe Article

  def after_create(record)
    expire_assigned_sections!(record) unless controller.nil? || record.status != :published
  end

  def after_save(record)
    return if controller.nil?
    expire_overview_feed! if record.is_a?(Article)
    pages = CachedPage.find_by_reference(record)
    controller.class.benchmark "Expired pages referenced by #{record.class} ##{record.id}" do
      pages.each { |p| controller.class.expire_page(p.url) }
      CachedPage.expire_pages(pages)
    end if pages.any?
  end

  alias after_destroy after_save

  protected
    def expire_overview_feed!
      controller.class.expire_page overview_url(:only_path => true, :skip_relative_url_root => true) if controller
    end
    
    def expire_assigned_sections!(record)
      record.send :save_assigned_sections
      record.sections.each do |section|
        controller.expire_page :sections => section.to_url,      :controller => '/mephisto', :action => 'list'
        controller.expire_page :sections => section.to_feed_url, :controller => '/feed',     :action => 'feed'
      end
    end
end