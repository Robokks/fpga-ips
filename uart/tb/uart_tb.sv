`timescale 1ns/1ps
// UART Loopback Testbench
// Uses fast parameters for simulation speed (10 MHz clk, 1 Mbps baud)
// Loopback: uart_top.tx -> uart_top.rx
// Sends 3 bytes and verifies received data matches

module uart_tb;

    // Parameters (fast for simulation)
    localparam CLK_FREQ  = 10_000_000;
    localparam BAUD_RATE = 1_000_000;
    localparam CLK_PERIOD = 1_000_000_000 / CLK_FREQ; // in ns = 100 ns

    // DUT signals
    logic       clk;
    logic       rst_n;
    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;
    logic       tx_line;
    logic [7:0] rx_data;
    logic       rx_valid;

    // Instantiate UART top (loopback: tx -> rx)
    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx       (tx_line),
        .rx       (tx_line),   // loopback
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    // Clock generation
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // VCD dump
    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);
    end

    // Test data
    localparam NUM_BYTES = 3;
    logic [7:0] test_bytes [0:NUM_BYTES-1];
    integer pass_count;
    integer i;

    // Task: send one byte via TX handshake
    task send_byte(input [7:0] data);
        @(posedge clk);
        wait (tx_ready);
        @(posedge clk);
        tx_data  <= data;
        tx_valid <= 1'b1;
        @(posedge clk);
        tx_valid <= 1'b0;
    endtask

    // Main test
    initial begin
        // Initialise
        rst_n    = 1'b0;
        tx_data  = 8'h00;
        tx_valid = 1'b0;
        pass_count = 0;

        test_bytes[0] = 8'hAB;
        test_bytes[1] = 8'hCD;
        test_bytes[2] = 8'hEF;

        // Hold reset for 5 cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // Send and verify all bytes
        for (i = 0; i < NUM_BYTES; i = i + 1) begin
            send_byte(test_bytes[i]);

            // Wait for RX to capture the byte
            wait (rx_valid);
            @(posedge clk);

            if (rx_data === test_bytes[i]) begin
                $display("[PASS] Byte %0d: sent=0x%02X  received=0x%02X", i, test_bytes[i], rx_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Byte %0d: sent=0x%02X  received=0x%02X", i, test_bytes[i], rx_data);
            end
        end

        // Summary
        repeat (4) @(posedge clk);
        $display("----------------------------");
        $display("Results: %0d / %0d PASSED", pass_count, NUM_BYTES);
        if (pass_count === NUM_BYTES)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("----------------------------");
        $finish;
    end

    // Timeout watchdog (10 ms sim time)
    initial begin
        #10_000_000;
        $display("[TIMEOUT] Simulation exceeded time limit");
        $finish;
    end

endmodule
