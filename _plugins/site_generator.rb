require 'date'
require 'fileutils'
require 'mini_magick'
require 'set'
require 'tqdm'
require 'xxhash'

module Jekyll

    def Jekyll::get_photo_hash(photo_data)
        XXhash.xxh32(photo_data['file'])
    end

    def Jekyll::get_photo_date(photo_data)
        Date.strptime(photo_data['file'], '%Y%m%d').strftime('%B %-d, %Y')
    end

    class PhotoPage < Page
        def initialize(site, base, dir, photo_data)
            @site = site
            @base = base
            @dir = dir
            @name = "/photo/#{photo_data['id']}/index.md"
            self.process(@name)
            self.data ||= {}
            self.data['layout'] = 'photo'
            self.data['photo'] = photo_data
        end
    end

    class CollectionPage < Page
        def initialize(site, base, dir, title, url, photo_arr, content='')
            @site = site
            @base = base
            @dir = dir
            @name = url
            self.process(@name)
            self.data ||= {}
            self.data['layout'] = 'collection'
            self.data['title'] = title
            self.data['photos'] = photo_arr
            self.data['content'] = content
        end
    end

    class HomePage < CollectionPage
        def initialize(site, base, dir, featured_photos, top_tags)
            super(site, base, dir, 'Home', '/index.md', featured_photos)
            self.data['layout'] = 'home'
            self.data['top_tags'] = top_tags
        end
    end

    class BrowseTagsPage < Page
        def initialize(site, base, dir)
            @site = site
            @base = base
            @dir = dir
            @name = '/tags/index.md'
            self.process(@name)
            self.data ||= {}
            self.data['layout'] = 'browse_tags'
        end
    end

    class ContactPage < Page
        def initialize(site, base, dir)
            @site = site
            @base = base
            @dir = dir
            @name = '/contact/index.md'
            self.process(@name)
            self.data ||= {}
            self.data['layout'] = 'contact'
        end
    end

    class SiteGenerator < Generator
        def generate(site)

            tags = Set.new
            FileUtils.mkdir_p('./assets/photos/preview')

            site.data['photos'].each do |photo_data|
                # add auto-generated metadata to photos
                photo_data['id'] = Jekyll::get_photo_hash(photo_data)
                photo_data['date'] = Jekyll::get_photo_date(photo_data)

                # add tags to tag set
                photo_data['tags'].each do |tag|
                    tags << tag
                end

                # create photo page
                photo_page = Jekyll::PhotoPage.new(
                    site, site.source, @dir, photo_data
                )
                site.pages << photo_page
            end

            # generate preview images
            if ENV['JEKYLL_ENV'] == 'production' or not File.directory?('_site/assets/photos/preview')
                puts "Generating preview images..."
                site.data['photos'].tqdm.each do |photo_data|
                    image = MiniMagick::Image.open("assets/photos/#{photo_data['file']}")
                    image.resize('40%')
                    image.write("assets/photos/preview/#{photo_data['file']}")
                    preview_file = Jekyll::StaticFile.new(site, site.source, 'assets/photos/preview/', photo_data['file'])
                    site.static_files << preview_file
                end
            end

            # generate tag page URLs
            site.data['tags'] = tags.to_a
            site.data['tag_urls'] = tags.to_a.map { |tag| [tag, tag.downcase
                                                                   .gsub(' ', '-')
                                                                   .gsub('(', '')
                                                                   .gsub(')', '')
                                                                   .gsub('/', '-')]}.to_h
            site.data['tag_counts'] = site.data['tags'].map { |tag| [
                tag, site.data['photos'].select { |photo| photo['tags'].include?(tag) }.length()
            ]}.to_h

            # generate tag pages
            site.data['tags'].each do |tag|
                tagged_photos = site.data['photos'].select { |photo| photo['tags'].include?(tag) }
                tag_page = Jekyll::CollectionPage.new(
                    site, site.source, @dir, "Tagged: #{tag}", "/tag/#{site.data['tag_urls'][tag]}/index.md", tagged_photos
                )
                site.pages << tag_page
            end

            # create "all photos" page
            all_photos_page = Jekyll::CollectionPage.new(
                site, site.source, @dir, 'All photos', '/photos/index.md', site.data['photos']
            )
            site.pages << all_photos_page

            # create "browse tags" page
            browse_tags_page = Jekyll::BrowseTagsPage.new(site, site.source, @dir)
            site.pages << browse_tags_page

            # create contact page
            contact_page = Jekyll::ContactPage.new(site, site.source, @dir)
            site.pages << contact_page

            # create homepage with featured photos
            featured_photos = site.data['photos'].select { |photo| photo['featured'] }
            home_page = Jekyll::HomePage.new(
                site, site.source, @dir, featured_photos,
                site.data['tag_counts'].sort_by{|k,v| -v}.to_h.keys.slice(0, 20)
            )
            site.pages << home_page

        end
    end

end