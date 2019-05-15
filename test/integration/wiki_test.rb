require File.expand_path('../../test_helper', __FILE__)

class WikiIntegrationTest < Redmine::IntegrationTest
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :wikis,
           :wiki_pages,
           :wiki_contents

  def test_updating_a_renamed_page
    log_user('jsmith', 'jsmith')

    get '/projects/ecookbook/wiki'
    assert_response :success

    get '/projects/ecookbook/wiki/Wiki/edit'
    assert_response :success

    # this update should not end up with a loss of content
    put '/projects/ecookbook/wiki/Wiki', params: {
      content: {
        text: "# Wiki\r\n\r\ncontent", comments:""
      },
      wiki_page: { parent_id: "" }
    }
    assert_redirected_to "/projects/ecookbook/wiki/Wiki"
    follow_redirect!
    assert_select 'div', /content/
    assert content = WikiContent.last

    # Let's assume somebody else, or the same user in another tab, renames the
    # page while it is being edited.
    post '/projects/ecookbook/wiki/Wiki/rename', params: { wiki_page: { title: "NewTitle" } }
    assert_redirected_to "/projects/ecookbook/wiki/NewTitle"

    # this update should not end up with a loss of content
    put '/projects/ecookbook/wiki/Wiki', params: {
      content: {
        version: content.version, text: "# Wiki\r\n\r\nnew content", comments:""
      },
      wiki_page: { parent_id: "" }
    }

    assert_redirected_to "/projects/ecookbook/wiki/NewTitle"
    follow_redirect!
    assert_select 'div', /new content/
  end

end

