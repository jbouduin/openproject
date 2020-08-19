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

require 'spec_helper'

describe ::Query::Results, 'sums', type: :model do
  let(:project) do
    FactoryBot.create(:project).tap do |p|
      p.work_package_custom_fields << int_cf
      p.work_package_custom_fields << float_cf
    end
  end
  let(:other_project) do
    FactoryBot.create(:project).tap do |p|
      p.work_package_custom_fields << int_cf
      p.work_package_custom_fields << float_cf
    end
  end
  let!(:work_package1) do
    FactoryBot.create(:work_package,
                      type: type,
                      project: project,
                      estimated_hours: 5,
                      done_ratio: 10,
                      "custom_field_#{int_cf.id}" => 10,
                      "custom_field_#{float_cf.id}" => 3.414)
  end
  let!(:work_package2) do
    FactoryBot.create(:work_package,
                      type: type,
                      project: project,
                      assigned_to: current_user,
                      done_ratio: 50,
                      estimated_hours: 5,
                      "custom_field_#{int_cf.id}" => 10,
                      "custom_field_#{float_cf.id}" => 3.414)
  end
  let!(:work_package3) do
    FactoryBot.create(:work_package,
                      type: type,
                      project: project,
                      assigned_to: current_user,
                      responsible: current_user,
                      done_ratio: 50,
                      estimated_hours: 5,
                      "custom_field_#{int_cf.id}" => 10,
                      "custom_field_#{float_cf.id}" => 3.414)
  end
  let!(:invisible_work_package1) do
    FactoryBot.create(:work_package,
                      type: type,
                      project: other_project,
                      estimated_hours: 5,
                      "custom_field_#{int_cf.id}" => 10,
                      "custom_field_#{float_cf.id}" => 3.414)
  end
  let(:int_cf) do
    FactoryBot.create(:int_wp_custom_field)
  end
  let(:float_cf) do
    FactoryBot.create(:float_wp_custom_field)
  end
  let(:type) do
    FactoryBot.create(:type).tap do |t|
      t.custom_fields << int_cf
      t.custom_fields << float_cf
    end
  end
  let(:current_user) do
    FactoryBot.create(:user,
                      member_in_project: project,
                      member_with_permissions: permissions)
  end
  let(:permissions) { %i[view_work_packages] }
  let(:group_by) { nil }
  let(:query) do
    FactoryBot.build :query,
                     project: project,
                     group_by: group_by
  end
  let(:query_results) do
    ::Query::Results.new query
  end

  before do
    login_as(current_user)
    Setting.work_package_list_summable_columns = ['estimated_hours', "cf_#{int_cf.id}", "cf_#{float_cf.id}"]
  end
  let(:estimated_hours_column) { query.available_columns.detect { |c| c.name.to_s == 'estimated_hours' } }
  let(:int_cf_column) { query.available_columns.detect { |c| c.name.to_s == "cf_#{int_cf.id}" } }
  let(:float_cf_column) { query.available_columns.detect { |c| c.name.to_s == "cf_#{float_cf.id}" } }

  describe '#all_total_sums' do
    it 'is a hash of all summable columns' do
      expect(query_results.all_total_sums)
        .to eql(estimated_hours_column => 15.0,
                int_cf_column => 30,
                float_cf_column => 10.24)
    end

    context 'when filtering' do
      before do
        query.add_filter('assigned_to_id', '=', [current_user.id.to_s])
      end

      it 'is a hash of all summable columns and includes only the work packages matching the filter' do
        expect(query_results.all_total_sums)
          .to eql(estimated_hours_column => 10.0,
                  int_cf_column => 20,
                  float_cf_column => 6.83)
      end
    end
  end

  describe '#all_sums_for_group' do
    context 'grouped by assigned_to' do
      let(:group_by) { :assigned_to }

      it 'is a hash of sums grouped by user values (and nil) and grouped columns' do
        expect(query_results.all_group_sums)
          .to eql(current_user => { estimated_hours_column => 10.0,
                                    int_cf_column => 20,
                                    float_cf_column => 6.83 },
                  nil => { estimated_hours_column => 5.0,
                           int_cf_column => 10,
                           float_cf_column => 3.41 })
      end

      context 'when filtering' do
        before do
          query.add_filter('responsible_id', '=', [current_user.id.to_s])
        end

        it 'is a hash of sums grouped by user values and grouped columns' do
          expect(query_results.all_group_sums)
            .to eql(current_user => { estimated_hours_column => 5.0,
                                      int_cf_column => 10,
                                      float_cf_column => 3.41 })
        end
      end
    end

    context 'grouped by done_ratio' do
      let(:group_by) { :done_ratio }

      it 'is a hash of sums grouped by done_ratio values and grouped columns' do
        expect(query_results.all_group_sums)
          .to eql(50 => { estimated_hours_column => 10.0,
                          int_cf_column => 20,
                          float_cf_column => 6.83 },
                  10 => { estimated_hours_column => 5.0,
                          int_cf_column => 10,
                          float_cf_column => 3.41 })
      end

      context 'when filtering' do
        before do
          query.add_filter('responsible_id', '=', [current_user.id.to_s])
        end

        it 'is a hash of sums grouped by done_ratio values and grouped columns' do
          expect(query_results.all_group_sums)
            .to eql(50 => { estimated_hours_column => 5.0,
                            int_cf_column => 10,
                            float_cf_column => 3.41 })
        end
      end
    end
  end
end