`timescale 1ns/1ps
// I2C Loopback Testbench
// Fast params: CLK_FREQ=10MHz, I2C_FREQ=500kHz
// Tests: write transaction (master→slave addr=0x50, data=0xBE)

module i2c_tb;

    localparam CLK_PERIOD  = 100; // 10 MHz → 100 ns period
    localparam CLK_FREQ    = 10_000_000;
    localparam I2C_FREQ    = 500_000;
    localparam [6:0] SLAVE_ADDR = 7'h50;

    // DUT signals
    logic       clk;
    logic       rst_n;
    logic       start;
    logic       rw;
    logic [6:0] addr;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic       busy;
    logic       ack_error;
    logic [7:0] slave_rx;
    logic       slave_rx_valid;
    logic [7:0] slave_tx;

    // Instantiate I2C top (loopback)
    i2c_top #(
        .CLK_FREQ   (CLK_FREQ),
        .I2C_FREQ   (I2C_FREQ),
        .SLAVE_ADDR (SLAVE_ADDR)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .rw             (rw),
        .addr           (addr),
        .data_in        (data_in),
        .data_out       (data_out),
        .busy           (busy),
        .ack_error      (ack_error),
        .slave_rx_data  (slave_rx),
        .slave_rx_valid (slave_rx_valid),
        .slave_tx_data  (slave_tx)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // VCD
    initial begin
        $dumpfile("i2c_sim.vcd");
        $dumpvars(0, i2c_tb);
    end

    integer pass_count;

    // Task: perform one I2C write transaction
    task i2c_write(input [6:0] a, input [7:0] d);
        @(posedge clk);
        addr    <= a;
        data_in <= d;
        rw      <= 1'b0;
        start   <= 1'b1;
        @(posedge clk);         // master samples start=1, busy rises next cycle
        start <= 1'b0;
        repeat(2) @(posedge clk); // allow busy to assert
        wait (busy);              // ensure transaction started
        wait (!busy);             // wait for completion
        @(posedge clk);
    endtask

    // Task: perform one I2C read transaction
    task i2c_read(input [6:0] a, input [7:0] slave_byte);
        @(posedge clk);
        addr     <= a;
        slave_tx <= slave_byte;
        rw       <= 1'b1;
        start    <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        repeat(2) @(posedge clk);
        wait (busy);
        wait (!busy);
        @(posedge clk);
    endtask

    initial begin
        rst_n      = 1'b0;
        start      = 1'b0;
        rw         = 1'b0;
        addr       = 7'h00;
        data_in    = 8'h00;
        slave_tx   = 8'hFF;
        pass_count = 0;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // ---- Test 1: Write 0xBE to slave 0x50 ----
        $display("--- Test 1: I2C Write (addr=0x%02X, data=0xBE) ---", SLAVE_ADDR);
        i2c_write(SLAVE_ADDR, 8'hBE);

        repeat (5) @(posedge clk);

        if (!ack_error && slave_rx === 8'hBE) begin
            $display("[PASS] Write: slave received 0x%02X, no ACK error", slave_rx);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Write: slave_rx=0x%02X  ack_error=%0b", slave_rx, ack_error);
        end

        repeat (20) @(posedge clk);

        // ---- Test 2: Write 0xA3 to slave 0x50 ----
        $display("--- Test 2: I2C Write (addr=0x%02X, data=0xA3) ---", SLAVE_ADDR);
        i2c_write(SLAVE_ADDR, 8'hA3);

        repeat (5) @(posedge clk);

        if (!ack_error && slave_rx === 8'hA3) begin
            $display("[PASS] Write: slave received 0x%02X, no ACK error", slave_rx);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Write: slave_rx=0x%02X  ack_error=%0b", slave_rx, ack_error);
        end

        repeat (10) @(posedge clk);

        // ---- Summary ----
        $display("----------------------------");
        $display("Results: %0d / 2 PASSED", pass_count);
        if (pass_count === 2)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("----------------------------");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #50_000_000; // 50 ms
        $display("[TIMEOUT] Simulation exceeded time limit");
        $finish;
    end

endmodule
