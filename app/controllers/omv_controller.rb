# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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

require 'open-uri'
require 'yaml'

class OmvController < ApplicationController
  before_filter :find_project_by_project_id
  
  
  def index
    
    
    @expectedAnalyzerOutputs = YAML::load(open('https://raw.githubusercontent.com/borismarin/osb-model-validation/master/omv/schemata/types/base/analyzer.yaml').read)
    @expectedDatafileOutputs = YAML::load(open('https://raw.githubusercontent.com/borismarin/osb-model-validation/master/omv/schemata/types/base/observable_datafile.yaml').read)
    @expectedLiteralOutputs = YAML::load(open('https://raw.githubusercontent.com/borismarin/osb-model-validation/master/omv/schemata/types/base/observable_literal.yaml').read)
    
    render
  end


end
