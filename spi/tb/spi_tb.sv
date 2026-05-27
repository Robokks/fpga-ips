`timescale 1ns/1ps
// SPI Loopback Testbench
// Verifies master sends / slave receives 3 bytes correctly
// CLK_DIV=2 for fast simulation

module spi_tb;

    localparam CLK_PERIOD = 10; // 10 ns → 100 MHz

    // DUT signals
    logic       clk;
    logic       rst_n;
    logic       start;
    logic [7:0] master_tx;
    logic [7:0] master_rx;
    logic       done;
    logic       busy;
    logic [7:0] slave_rx;
    logic       slave_rx_valid;
    logic [7:0] slave_tx;

    // Instantiate SPI top (loopback)
    spi_top #(
        .CLK_DIV (2),
        .CPOL    (0),
        .CPHA    (0)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .master_tx_data (master_tx),
        .master_rx_data (master_rx),
        .done           (done),
        .busy           (busy),
        .slave_rx_data  (slave_rx),
        .slave_rx_valid (slave_rx_valid),
        .slave_tx_data  (slave_tx)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // VCD
    initial begin
        $dumpfile("spi_sim.vcd");
        $dumpvars(0, spi_tb);
    end

    // Test data
    localparam NUM_BYTES = 3;
    logic [7:0] test_bytes [0:NUM_BYTES-1];
    integer pass_count;
    integer i;

    // Task: perform one SPI transfer
    task spi_transfer(input [7:0] tx_byte);
        @(posedge clk);
        master_tx <= tx_byte;
        slave_tx  <= ~tx_byte; // slave echoes inverted (just to have something to send back)
        start     <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        // Wait for done
        wait (done);
        @(posedge clk);
    endtask

    initial begin
        rst_n      = 1'b0;
        start      = 1'b0;
        master_tx  = 8'h00;
        slave_tx   = 8'hFF;
        pass_count = 0;

        test_bytes[0] = 8'hA5;
        test_bytes[1] = 8'h3C;
        test_bytes[2] = 8'hF0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        for (i = 0; i < NUM_BYTES; i = i + 1) begin
            spi_transfer(test_bytes[i]);

            // Check slave received the correct byte
            if (slave_rx === test_bytes[i]) begin
                $display("[PASS] Transfer %0d: master_tx=0x%02X  slave_rx=0x%02X",
                         i, test_bytes[i], slave_rx);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Transfer %0d: master_tx=0x%02X  slave_rx=0x%02X",
                         i, test_bytes[i], slave_rx);
            end

            repeat (4) @(posedge clk); // gap between transfers
        end

        $display("----------------------------");
        $display("Results: %0d / %0d PASSED", pass_count, NUM_BYTES);
        if (pass_count === NUM_BYTES)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $display("----------------------------");
        $finish;
    end

    // Timeout
    initial begin
        #500_000;
        $display("[TIMEOUT] Simulation exceeded time limit");
        $finish;
    end

endmodule
