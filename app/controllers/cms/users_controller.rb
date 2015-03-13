class Cms::UsersController < ApplicationController
  include Cms::BaseFilter
  include Cms::CrudFilter
  include Cms::SearchableCrudFilter

  model Cms::User

  navi_view "cms/main/navi"
  menu_view "cms/users/menu" ### TODO 2コントローラー

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

    ### TODO 2コントローラー
    # 要調整、コード量が多くなるならconcernにまとめたりしたほうがよいかもしれない
    # 似たような箇所は History::Cms::LogsController

    def download
      require "csv"

      header = ["name", "email", "type", "groups", "cms_roles"]

      CSV.generate(list = "", :headers => header, :write_headers => true) do |csv|
        @model.site(@cur_site).each do |u|
          csv << [u.name, u.email, u.type, u.groups.map {|e| e.name}.join("\n"), u.cms_roles.map {|e| e.name}.join("\n")]
        end
      end
      
      send_data(list, :type => 'text/csv', :filename => 'users.csv')
    end

    def import
      return if request.get? # if get request, render view only

      ### TODO 4インポートロジック
      # CSVからユーザーをインポートする
      # 以下のような感じ?
      #
      # csv.each do |row|
      #
      #   update Cms::User collection from row
      #
      # end
      #

    end
end
