require 'mongoid'

#module RCS
#module DB

class Alert
  include RCS::Tracer
  extend RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :type, type: String
  field :suppression, type: Integer
  field :tag, type: Integer
  field :path, type: Array
  field :action, type: String
  field :evidence, type: String
  field :keywords, type: String
  field :entities, type: Array, default: []
  field :last, type: Integer

  index({enabled: 1}, {background: true})
  index({path: 1}, {background: true})

  store_in collection: 'alerts'

  belongs_to :user, index: true
  embeds_many :logs, class_name: "AlertLog"

  def delete_if_item(id)
    if self.path.include? id
      trace :debug, "Deleting Alert because it contains #{id}"
      self.destroy
    end
  end

  def update_path(replace)
    trace :debug, "Updating alert #{id} path: #{replace.inspect}"

    replace.each { |position, value| self.path[position] = value }

    self.logs.destroy_all
    self.last = nil

    save
  end

  def self.destroy_old_logs
    trace :debug, "Cleaning old alerts..."

    # delete the alerts older than a week
    all.each do |alert|
      alert.logs.destroy_all(:time.lt => Time.now.getutc.to_i - 86400*7)
    end
  end
end


class AlertLog
  include Mongoid::Document

  field :time, type: Integer
  field :path, type: Array
  field :evidence, type: Array, default: []
  field :entities, type: Array, default: []

  embedded_in :alert

  after_destroy :reset_alert_last_triggered
  after_create :update_alert_last_triggered

  def reset_alert_last_triggered
    self._parent.last = nil if self._parent.logs.empty?
  end

  def update_alert_last_triggered
    self._parent.last = self.time
  end
end

#end # ::DB
#end # ::RCS