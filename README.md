# vivadoプロジェクトの作成方法

本ソースコードをvivado上でビルドするには以下の手順を踏む。

1. vivadoで`nexys a7 100t`向けのRTLプロジェクトを作成する。
2. `Add Sources`を押し、`Add or create design sources`を選択して`next`を押す。
3. `Add Directories`を押し、本ソースコードのディレクトリを追加する。このとき、`Copy sources into project`にチェックが入っているようにすること。
4. ここまででmemファイル、constraintファイル以外は追加される。もう一度`Add Sources -> Add or create design sources`を押し、`Add Files`からfpuディレクトリ下とcacheディレクトリ下のmemファイル4つを追加する。
5. 最後に、`Add Sources -> Add or create constraints -> Add Files`からconstraintディレクトリ下のxdcファイルを追加する。
6. 以上でファイルの追加は終了。次にSourcesのモジュールツリーを`Design Sources -> top -> board -> conn -> dram_controller`と展開し、`mig_7series_0`を見つける。
7. これを右クリックし、`Generate Output Products -> Generate`を押す。
8. 以上でbit streamを生成できる状態になったはずである。