# このシェルにおいてはABIは以下とする
# - r0 ~ r15レジスタは汎用レジスタであり、保存の必要はない
# - 戻り値はr0 ~ r15に入れて返す
# - 引数はr0 ~ r15に入れて渡す
# - r200 ~ はレジスタ上のヒープとする

init:
    # r200はMMIOのアドレス (書き込み)
    addi r200, zero, -12
    # r201はMMIOのアドレス (書き込み可能バイト数)
    addi r201, zero, -8
    # r202はMMIOのアドレス (受信バイト数)
    addi r202, zero, -14
    # r203はMMIOのアドレス (受信)
    addi r203, zero, -15

    # r204は">>> "という文字列
    # 文字コード
    # - 0x3e: >
    # - 0x20: space
    addi r204, zero, 0x3e
    slli r204, r204, 8
    addi r204, r204, 0x3e
    slli r204, r204, 8
    addi r204, r204, 0x3e
    slli r204, r204, 8
    addi r204, r204, 0x20

    # fp, spを用いてキューを表現することにする
    addi fp, zero, 1
    slli fp, fp, 9
    add sp, zero, fp

loop:
    # 文字列が書き込めるようになるまで待つ
    lw r0, r201
    beq r0, zero, loop
    
    # ">>> "という文字列の表示
    sw r204, r200

loop1:
    # 文字列を受信するまで待つ
    lw r0, r202
    beq r0, zero, loop1

    # 受信した文字列をすべて読み、表示する
loop2:
    lw r1, r203
    
    # 受信したワードに改行が含まれているかをチェック
    addi r10, zero, 0
    addi r11, zero, 32
loop3:
    sll r2, r1, r10
    srli r2, r2, 24
    addi r2, r2, -0x0a
    beq r2, zero, lf_found
    addi r10, r10, 8
    beq r10, r11, lf_not_found
    j loop3
lf_found:
    addi r10, r10, 8
    sll r2, r1, r10
    srl r2, r2, r10
    sub r1, r1, r2
    w1: lw r3, r201
    beq r3, zero, w1
    sw r1, r200
    sw r1, sp
    add r12, zero, fp
for:
    lw r1, r12
    w2: lw r3, r201
    beq r3, zero, w2
    sw r1, r200
    addi r12, r12, 1
    ble r12, sp, for
    add sp, zero, fp
    j break1
lf_not_found:
    lw r3, r201
    beq r3, zero, lf_not_found
    sw r1, r200
    sw r1, sp
    addi sp, sp, 1

    addi r0, r0, -1
    blt zero, r0, loop2
    j loop1

break1:
    j loop
