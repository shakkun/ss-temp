class Ezine::Page
  include Cms::Page::Model
  include Cms::Addon::Release
  include Cms::Addon::ReleasePlan
  include Ezine::Addon::Page::Body

  field :results, type: Array, default: []
  field :completed, type: Boolean, default: false

  before_save :seq_filename, if: ->{ basename.blank? }

  default_scope ->{ where(route: "ezine/page") }

  public
    # Get members to deliver this page.
    #
    # Return an empty array when a delivery is completed.
    #
    # Return members array not included in sent logs when a delivery is
    # incompleted.
    #
    # このページを配信するべきメンバー一覧を取得する。
    #
    # 配信が完了していれば空の配列が返る。
    #
    # 配信が完了していない場合は配信ログが存在しないメンバー一覧が返る。
    #
    # @return [Array<Ezine::Member>]
    #   Members to deliver.
    #
    #   配信するべきメンバー一覧。
    def members_to_deliver
      return [] if completed
      emails = Ezine::SentLog.where(page_id: id).map(&:email)
      Ezine::Member.where(node_id: parent.id, email: {"$nin" => emails})
    end

    # Deliver a mail to a member.
    #
    # Create a sent log if it is succeeded and isn't test delivery.
    #
    # 1メンバーにメールを配信する。
    #
    # 成功しかつテスト配信でなければ配信ログを作成する。
    #
    # @param [Ezine::Member, Ezine::TestMember] member
    #
    # @raise [Object]
    #   An error object from `ActionMailer#deliver`
    #
    #   `ActionMailer#deliver` メソッドからのエラーオブジェクト
    def deliver_to(member)
      Ezine::Mailer.page_mail(self, member).deliver
      Ezine::SentLog.create(
        node_id: parent.id, page_id: id, email: member.email
      ) unless member.test_member?
    end

    # Do a test delivery.
    #
    # テスト配信を行う。
    def deliver_to_test_members
      Ezine::TestMember.where(node_id: parent.id).each do |test_member|
        deliver_to test_member
      end
    end

  private
    def validate_filename
      @basename.blank? ? nil : super
    end

    def seq_filename
      self.filename = dirname ? "#{dirname}#{id}.html" : "#{id}.html"
    end
end
