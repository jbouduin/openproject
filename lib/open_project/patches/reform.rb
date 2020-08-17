#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module OpenProject
  module Patches
    module Reform
      def merge!(errors, prefix = [])
        @store_new_symbols = false
        super(errors, prefix)
        @store_new_symbols = true

        errors.keys.each do |attribute|
          errors.symbols_and_messages_for(attribute).each do |symbol, full_message, partial_message|
            symbols_and_messages = writable_symbols_and_messages_for(attribute)
            next if symbols_and_messages && symbols_and_messages.any? do |sam|
              sam[0] === symbol &&
              sam[1] === full_message &&
              sam[2] === partial_message
            end

            symbols_and_messages << [symbol, full_message, partial_message]
          end
        end
      end
    end
  end
end

require "reform/form/active_model/validations"

Reform::Form.class_eval do
  include Reform::Form::ActiveModel::Validations
end

Reform::Contract.class_eval do
  include Reform::Form::ActiveModel::Validations
end

Reform::Form::ActiveModel::Validations::Validator.class_eval do
  ##
  # use activerecord as the base scope instead of 'activemodel' to be compatible
  # to the messages we have already stored
  def self.i18n_scope
    :activerecord
  end
end

require 'reform/contract'

class Reform::Form::ActiveModel::Errors
  prepend OpenProject::Patches::Reform
end

class Reform::Form::Validations::Result::ResultErrors
  # Override gem method completely to allow passing error params to the
  # ActiveModel error objects. This allows parameterizing error messages e.g.
  # add(:some_property, :greater_than, count: 0)
  def add(key, error_text, error_params = {})
    # use rails magic to get the correct error_text and make sure we still update details and fields
    text = @amv_errors.add(key, error_text, error_params)

    # using error_text instead of text to either keep the symbol which will be
    # magically replaced with the translate or directly the string - this is also
    # required otherwise in the custom_errors method we will add the actual message in the
    # ActiveModel::Errors#details which is not correct if a symbol was passed here
    Reform::Contract::CustomError.new(key, error_text, @result.to_results)

    # but since messages method is actually already defined in `Reform::Contract::Result::Errors
    # we need to update the @dotted_errors instance variable to add or merge a new error
    @dotted_errors.key?(key) ? @dotted_errors[key] |= text : @dotted_errors[key] = text
    instance_variable_set(:@dotted_errors, @dotted_errors)
  end

  def merge!(ar_errors)
    ar_errors.details.each do |identifier, details|
      details.each do |detail|
        error_detail = detail.dup
        error_symbol = detail.delete(:error)
        add(identifier, error_symbol, error_detail)
      end
    end
  end
end
