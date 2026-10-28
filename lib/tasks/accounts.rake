# frozen_string_literal: true

# rake のタスク定義は1つの namespace ブロックにまとまるため、行数の制限は対象外にする
# rubocop:disable-next Metrics/BlockLength
namespace :accounts do
  # 招待URLのホスト部分。本番では APP_URL=https://example.com を指定する
  app_url = -> { ENV.fetch('APP_URL', 'http://localhost:3000') }

  desc '会社の管理者を作り、招待URLを表示する: ORGANIZATION=会社名 NAME=名前 EMAIL=メール [APP_URL=https://...]'
  task create_admin: :environment do
    result = AdminAccountCreator.call(
      organization_name: ENV.fetch('ORGANIZATION'), name: ENV.fetch('NAME'), email: ENV.fetch('EMAIL')
    )

    $stdout.write("管理者を作成しました: #{result.user.email}\n" \
                  "招待URL（7日間・1回のみ有効）: #{InvitationLink.url(result.invitation_token, app_url.call)}\n")
  end

  desc '運営アカウントを作り、招待URLを表示する: NAME=名前 EMAIL=メール [ORGANIZATION=運営] [APP_URL=https://...]'
  task create_operator: :environment do
    result = AdminAccountCreator.call(
      organization_name: ENV.fetch('ORGANIZATION', '運営'), name: ENV.fetch('NAME'), email: ENV.fetch('EMAIL'),
      role: :operator
    )

    $stdout.write("運営アカウントを作成しました: #{result.user.email}\n" \
                  "招待URL（7日間・1回のみ有効）: #{InvitationLink.url(result.invitation_token, app_url.call)}\n")
  end

  desc '環境変数から最初の管理者を作る（作成済み・未設定なら何もしない）: INITIAL_ADMIN_ORGANIZATION/NAME/EMAIL'
  task ensure_admin: :environment do
    email = ENV.fetch('INITIAL_ADMIN_EMAIL', nil)
    next if email.blank? || User.exists?(email: email)

    result = AdminAccountCreator.call(
      organization_name: ENV.fetch('INITIAL_ADMIN_ORGANIZATION'), name: ENV.fetch('INITIAL_ADMIN_NAME'), email: email
    )

    $stdout.write("最初の管理者を作成しました: #{email}\n" \
                  "招待URL（7日間・1回のみ有効）: #{InvitationLink.url(result.invitation_token, app_url.call)}\n")
  end

  desc '既存ユーザーの招待URLを再発行する: EMAIL=メール [APP_URL=https://...]'
  task invite: :environment do
    user = User.find_by!(email: ENV.fetch('EMAIL'))

    $stdout.write("招待URL（7日間・1回のみ有効）: #{InvitationLink.url(user.issue_invitation_token!, app_url.call)}\n")
  end
end
