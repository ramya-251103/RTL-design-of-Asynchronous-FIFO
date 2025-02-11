`timescale 1ns/1ps

module fifo_tb;

    // Parameters
    parameter DATA_WIDTH = 8;
    parameter PTR_WIDTH = 3;
    parameter DEPTH = 8;

    // Signals
    reg wclk, rclk, wrst_n, rrst_n, w_en, r_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full, empty;

    // Instantiate Top Module
    fifo_top #(
        .DATA_WIDTH(DATA_WIDTH), 
        .PTR_WIDTH(PTR_WIDTH), 
        .DEPTH(DEPTH)
    ) fifo_inst (
        .wclk(wclk),
        .rclk(rclk),
        .wrst_n(wrst_n),
        .rrst_n(rrst_n),
        .w_en(w_en),
        .r_en(r_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    // Clock Generation
    initial begin
        wclk = 0;
        forever #5 wclk = ~wclk;
    end

    initial begin
        rclk = 0;
        forever #7 rclk = ~rclk;
    end

    // Reset and Stimulus
    initial begin
        // Initial reset setup
        wrst_n = 0;
        rrst_n = 0;
        w_en = 0;
        r_en = 0;
        data_in = 0;

        // Release resets with sufficient delay
        #20;
        wrst_n = 1;  // Release write reset
        #20;
        rrst_n = 1;  // Release read reset
        #20;

        // Test: Write data to FIFO until it's full
        @(negedge wclk);
        w_en = 1;
        repeat (DEPTH) begin
            data_in = data_in + 1;
            @(negedge wclk);
        end
        w_en = 0;

        // Test: Read data from FIFO until it's empty
        @(negedge rclk);
        r_en = 1;
        while (!empty) begin
            @(negedge rclk);
        end
        r_en = 0;

        // Check Full and Empty Conditions
        #20;
        data_in = 8'hFF;  // Changing data pattern
        @(negedge wclk);
        w_en = 1;
        @(posedge full);  // Wait until full
        w_en = 0;

        #20;
        @(negedge rclk);
        r_en = 1;
        @(posedge empty); // Wait until empty
        r_en = 0;

        // End Simulation
        #100;
        $stop;
    end

    // Monitor output for debugging
    initial begin
        $monitor("Time=%0t | wclk=%b | rclk=%b | w_en=%b | r_en=%b | data_in=%h | data_out=%h | full=%b | empty=%b",
                 $time, wclk, rclk, w_en, r_en, data_in, data_out, full, empty);
    end

    // Check that writing does not occur when full
    always @(posedge wclk) begin
        if (full && w_en) begin
            $display("Error: Write attempt when FIFO is full at time %0t", $time);
            $stop;
        end
    end

    // Check that reading does not occur when empty
    always @(posedge rclk) begin
        if (empty && r_en) begin
            $display("Error: Read attempt when FIFO is empty at time %0t", $time);
            $stop;
        end
    end

    // Generate VCD for waveform analysis
    initial begin
        $dumpfile("fifo_waveform.vcd");
        $dumpvars(0, fifo_tb);
    end

endmodule
