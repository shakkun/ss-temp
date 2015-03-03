class Cms::UsersController < ApplicationController
  include Cms::BaseFilter
  include Cms::CrudFilter
  include Cms::SearchableCrudFilter

  model Cms::User

  navi_view "cms/main/navi"
  menu_view "cms/users/menu"

  private
    def set_crumbs
      @crumbs << [:"cms.user", action: :index]
    end

    def set_item
      super
      raise "403" unless Cms::User.site(@cur_site).include?(@item)
    end

  public
    def update
      other_group_ids = Cms::Group.nin(id: Cms::Group.site(@cur_site).pluck(:id)).in(id: @item.group_ids).pluck(:id)
      other_role_ids = Cms::Role.nin(id: Cms::Role.site(@cur_site).pluck(:id)).in(id: @item.cms_role_ids).pluck(:id)

      @item.attributes = get_params
      raise "403" unless @item.allowed?(:edit, @cur_user, site: @cur_site)
      @item.update

      @item.add_to_set(group_ids: other_group_ids)
      @item.add_to_set(cms_role_ids: other_role_ids)
      raise "403" unless @item.allowed?(:edit, @cur_user, site: @cur_site)
      render_update @item.update
    end
    
  def download
    require "csv"

    header = ["name", "email", "type", "groups", "cms_roles"]

    group_ids = { "1" => "シラサギ市", "2" => "シラサギ市/企画政策部", "3" => "シラサギ市/企画政策部/広報課", "4" => "シラサギ市/企画政策部/政策課", "5" => "シラサギ市/危機管理部", "6" => "シラサギ市/危機管理部/管理課", "7" => "シラサギ市/危機管理部/防災課" }
    cms_role_ids = { "1" => "サイト管理者", "2" => "記事編集権限" }

    CSV.generate(list = "", :headers => header, :write_headers => true) do |csv|
      @model.each do |u|
        csv << [u.name, u.email, group_ids["#{u.group_ids.join("\n")}"], cms_role_ids["#{u.cms_role_ids.join("\n")}"]]
      end
    end

    send_data(list, :type => 'text/csv', :filename => 'users.csv')
  end
end
