require 'settingslogic'

module Turqlom
  def self.env
    @@env ||= "development"
  end

  def self.env=(environment)
    @@env = environment
  end
end

class Turqlom::Settings < Settingslogic
  namespace Turqlom.env
end
