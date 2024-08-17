require 'open3'
require 'date'

# Wi-Fiの電波強度、リンク品質、ビットレート、ESSID、周波数帯を取得し、評価を付けるメソッド
def get_signal_level(interface)
  # iwconfigコマンドを使用して、指定されたインターフェースの情報を取得する
  # iwconfig [object]で欲しいオブジェクトを取得できる
  command = "iwconfig #{interface}"
  stdout, stderr, status = Open3.capture3(command)

  # コマンドが成功した場合にのみ処理を行う
  if status.success?
    result = ""

    # ESSIDの取得
    # ESSIDはWi-Fiネットワークの名前を指し、ネットワーク名を抽出する
    if stdout =~ /ESSID:"(.+?)"/
      essid = $1
      result += "ネットワーク名: #{essid}、"
    end
    
    # Frequencyの取得と周波数帯の評価
    # FrequencyはWi-Fiが使用している周波数を示し、通常は2.4GHzまたは5GHz
    if stdout =~ /Frequency:(\d+\.\d+) GHz/
      frequency = $1.to_f
      # 2.4GHz帯は範囲が広く干渉を受けやすいが、5GHz帯は速度が速く干渉が少ない
      frequency_band = frequency < 3 ? "2.4GHz帯" : "5GHz帯"
      result += "周波数帯: #{frequency} GHz（#{frequency_band}）、"
    end

    # Signal Levelの評価
    # Signal levelはWi-Fi信号の強度を示し、dBm（デシベルミリワット）で表される
    # 一般的に、信号強度が-50 dBm以上は非常に良好、-60 dBmで良好、-70 dBmで普通、-80 dBm以下は弱いとされる
    if stdout =~ /Signal level=(-?\d+ dBm)/
      signal_level = $1
      signal_value = $1.to_i
      # 各信号強度範囲に応じて評価を行う
      signal_quality = case signal_value
                       when -30..-50 then "優良"   # 非常に強い信号
                       when -51..-60 then "良好"   # 十分な強度
                       when -61..-70 then "普通"   # やや弱いが許容範囲
                       when -71..-80 then "弱い"   # 弱い信号
                       else "非常に弱い"          # 極めて弱い、接続に問題が生じる可能性がある
                       end
      result += "信号強度: #{signal_level}（#{signal_quality}）、"
    end

    # Link Qualityの評価
    # Link Qualityは、Wi-Fi接続の全体的な品質を示し、X/Yの形式で表示される
    # 一般的に、80%以上は非常に良好、60-79%は良好、40-59%は普通、40%未満は弱いとされる
    if stdout =~ /Link Quality=(\d+)\/(\d+)/
      link_quality = $1.to_i
      max_quality = $2.to_i
      # リンク品質の割合を計算して評価を行う
      quality_ratio = (link_quality.to_f / max_quality.to_f) * 100
      link_quality_description = case quality_ratio
                                 when 80..100 then "優良"  # 接続が非常に安定している
                                 when 60..79 then "良好"   # 安定した接続
                                 when 40..59 then "普通"   # 一部不安定な可能性がある
                                 else "弱い"              # 接続が不安定
                                 end
      result += "リンク品質: #{link_quality}/#{max_quality}（#{link_quality_description}）、"
    end

    # Bit Rateの評価
    # Bit Rateは、Wi-Fi接続のデータ転送速度を示し、通常はMbps（メガビット毎秒）で表示される
    # 一般的に、100 Mbps以上は非常に良好、50-99 Mbpsは良好、20-49 Mbpsは普通、20 Mbps未満は弱いとされる
    if stdout =~ /Bit Rate=(\d+\.?\d*) Mb\/s/
      bit_rate = $1.to_f
      # ビットレートの値に応じて評価を行う
      bit_rate_description = case bit_rate
                             when 100..Float::INFINITY then "優良"  # 非常に高速
                             when 50...100 then "良好"              # 高速
                             when 20...50 then "普通"               # 一般的な速度
                             else "弱い"                           # 低速、接続に問題が生じる可能性がある
                             end
      result += "ビットレート: #{bit_rate} Mb/s（#{bit_rate_description}）"
    end

    # 現在の日時を追加
    timestamp = DateTime.now.strftime("%Y年%m月%d日 %H:%M:%S")
    return "#{timestamp}  #{result}"
  else
    # コマンドの実行に失敗した場合のエラーメッセージ
    puts "コマンドの実行に失敗しました: #{stderr}"
    return nil
  end
end

# 20回繰り返して信号強度を測定する
30.times do
  begin
    # Wi-Fiの情報を取得して表示
    signal_info = get_signal_level("wlan0")
    # signal_infoがnilでない場合にのみ出力する
    puts signal_info if signal_info
    sleep 3  # 3秒待機してから次の測定を行う
  rescue Interrupt
    # ユーザーがCtrl+Cを押した場合に測定を終了する
    puts "測定を終了しました。"
    break
  end
end
