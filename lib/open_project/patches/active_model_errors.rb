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

# This patch should no longer be necessary.
# But we have references to symbolds_and_messages_for as well as for symbols_for all over
# the code base.
module OpenProject::ActiveModelErrorsPatch
  def symbols_and_messages_for(attribute)
    symbols = details[attribute].map { |e| e[:error] }
    messages = full_messages_for(attribute)

    symbols.zip(messages)
  end

  def symbols_for(attribute)
    details[attribute].map { |r| r[:error] }
  end

  #def full_message(attribute, message)
  #  return message if attribute == :base

  #  # if a model acts_as_customizable it will inject attributes like 'custom_field_1' into itself
  #  # using attr_name_override we resolve names of such attributes.
  #  # The rest of the method should reflect the original method implementation of ActiveModel
  #  attr_name_override = nil
  #  match = /\Acustom_field_(?<id>\d+)\z/.match(attribute)
  #  if match
  #    attr_name_override = CustomField.find_by(id: match[:id]).name
  #  end

  #  attr_name = attribute.to_s.tr('.', '_').humanize
  #  attr_name = @base.class.human_attribute_name(attribute, default: attr_name)
  #  I18n.t(:"errors.format",                                default: '%{attribute} %{message}',
  #                                                          attribute: attr_name_override || attr_name,
  #                                                          message: message)
  #end
end

ActiveModel::Errors.prepend(OpenProject::ActiveModelErrorsPatch)
# Activate being able to specify the format in which full_message works.
# Doing this, it is e.g. possible to avoid having the format of '%{attribute} %{message}' which
# will always prepend the attribute name to the error message.
ActiveModel::Errors.i18n_customize_full_message = true
