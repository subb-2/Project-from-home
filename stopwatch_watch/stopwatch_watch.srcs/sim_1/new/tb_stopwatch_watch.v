`timescale 1ns / 1ps

module tb_stopwatch_watch();

    // 입력 신호 선언 (reg)
    reg clk;
    reg reset;
    reg [3:0] sw;
    reg btn_r;
    reg btn_l;
    reg btn_u;
    reg btn_d;

    // 출력 신호 관찰 (wire)
    wire [3:0] fnd_digit;
    wire [7:0] fnd_data;

    // DUT (Device Under Test) 인스턴스화
    top_stopwatch_watch dut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .btn_r(btn_r),
        .btn_l(btn_l),
        .btn_u(btn_u),
        .btn_d(btn_d),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

    // 100MHz 클락 생성 (10ns 주기)
    always #5 clk = ~clk;

    initial begin
        // 초기화
        clk = 0;
        reset = 1;
        sw = 4'b0000;
        btn_r = 0;
        btn_l = 0;
        btn_u = 0;
        btn_d = 0;

        // 리셋 해제
        #10;
        reset = 0;
        #100;

        // --- 시나리오 1: 스톱워치 동작 테스트 ---
        sw[1] = 0;       // 스톱워치 선택
        sw[0] = 0;       // Up Count 모드
        
        #500_000_000;
        btn_r = 1;  // Run 버튼 누름
        #500_000_000;
        btn_r = 0;
        
        // 100Hz 틱이 발생할 때까지 대기 (시뮬레이션 가속을 위해 tick_gen의 F_COUNT를 줄이는 것이 좋음)
        #1000_000; 

        // --- 시나리오 2: 시계 모드 전환 및 시간 설정 ---
        $display("Scenario 2: Watch Mode and Set Time");
        sw[1] = 1;       // 시계 모드 선택
        sw[3] = 0;       // 분(Minute) 설정 모드
        
        #500_000_000;
        btn_u = 1;  // 분 증가 버튼 누름
        #500_000_000;
        btn_u = 0;
        
        #500_000_000;
        sw[3] = 1;  // 시(Hour) 설정 모드로 변경
        #500_000_000;
        btn_u = 1;  // 시 증가 버튼 누름
        #500_000_000;
        btn_u = 0;

        // --- 시나리오 3: 클리어 기능 테스트 ---
        #500_000_000;
        btn_l = 1;  // Clear 버튼
        #500_000_000;
        btn_l = 0;

        // 충분히 관찰 후 종료
        #1000_000_000;
        $stop;
    end

endmodule