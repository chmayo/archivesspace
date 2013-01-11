class Location < Sequel::Model(:location)
  include ASModel
  include ExternalIDs

  set_model_scope :repository
  corresponds_to JSONModel(:location)


  def self.generate_title(json)
    title = ""

    title << json['building']
    title << ", #{json['floor']}" if json['floor']
    title << ", #{json['room']}" if json['room']
    title << ", #{json['area']}" if json['area']

    others = []
    others << json['barcode'] if json['barcode']
    others << json['classification'] if json['classification']
    others << "#{json['coordinate_1_label']}: #{json['coordinate_1_indicator']}" if json['coordinate_1_label']
    others << "#{json['coordinate_2_label']}: #{json['coordinate_2_indicator']}" if json['coordinate_2_label']
    others << "#{json['coordinate_3_label']}: #{json['coordinate_3_indicator']}" if json['coordinate_3_label']

    title << " [#{others.join(", ")}]"

    title
  end

  def self.create_from_json(json, opts = {})
    json['title'] = generate_title(json)
    super
  end


  def update_from_json(json, opts = {})
    json['title'] = generate_title(json)
    super
  end

end
