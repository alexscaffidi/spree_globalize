module Spree
  module ProductDecorator
    def self.prepended(base)
      base.translates :name, :description, :meta_title, :meta_description, :meta_keywords, :slug, fallbacks_for_empty_translations: true
      base.friendly_id :slug_candidates, use: [:history, :globalize]

      def base.like_any(fields, values)
        translations = Spree::Product::Translation.arel_table
        source = fields.product(values, [translations, arel_table])
        clauses = source.map do |(field, value, arel)|
          arel[field].matches("%#{value}%")
        end.inject(:or)

        joins(:translations).where(translations[:locale].eq(I18n.locale)).where(clauses)
      end
    end

    Spree::Product.include SpreeGlobalize::Translatable

    module Translation
      def self.prepended(base)
        base.acts_as_paranoid
        base.after_destroy :punch_slug
        Spree::Product::Translation.default_scopes = []

        def base.punch_slug
          update(slug: "#{Time.now.to_i}_#{slug}")
        end
      end
    end

    # Don't punch slug on original product as it prevents bulk deletion.
    # Also we don't need it, as it is translated.
    def punch_slug; end

    def duplicate_extra(old_product)
      duplicate_translations(old_product)
    end

    def property(property_name)
      product_properties.joins(:property).find_by(spree_properties: { id: Spree::Property.find_by(name: property_name) }).try(:value)
    end

    private

    def duplicate_translations(old_product)
      old_product.translations.each do |translation|
        translation.slug = nil # slug must be regenerated
        self.translations << translation.dup
      end
    end
  end
end

Spree::Product.prepend Spree::ProductDecorator
