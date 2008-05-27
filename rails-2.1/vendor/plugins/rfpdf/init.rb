require 'rfpdf'

ActionView::Template::register_template_handler 'rfpdf', RFPDF::View
