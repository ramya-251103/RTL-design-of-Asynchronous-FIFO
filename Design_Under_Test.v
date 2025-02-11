// Write Pointer Handler
module wptr_handler #(parameter PTR_WIDTH=3) (
    input wclk, wrst_n, w_en,
    input [PTR_WIDTH:0] g_rptr_sync,
    output reg [PTR_WIDTH:0] b_wptr, g_wptr,
    output reg full
);
    reg [PTR_WIDTH:0] b_wptr_next;
    reg [PTR_WIDTH:0] g_wptr_next;

    // Next binary write pointer value calculation
    always @(*) begin
        b_wptr_next = b_wptr + (w_en & !full);
        // Convert binary to Gray code for crossing domains
        g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;
    end

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            b_wptr <= 0;
            g_wptr <= 0;
        end else begin
            b_wptr <= b_wptr_next;
            g_wptr <= g_wptr_next;
        end
    end

    // Full condition logic with wrap-around detection
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) 
            full <= 0;
        else 
            full <= (g_wptr_next == {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1], g_rptr_sync[PTR_WIDTH-2:0]});
    end
endmodule

// Read Pointer Handler
module rptr_handler #(parameter PTR_WIDTH=3) (
    input rclk, rrst_n, r_en,
    input [PTR_WIDTH:0] g_wptr_sync,
    output reg [PTR_WIDTH:0] b_rptr, g_rptr,
    output reg empty
);
    reg [PTR_WIDTH:0] b_rptr_next;
    reg [PTR_WIDTH:0] g_rptr_next;

    // Next binary read pointer value calculation
    always @(*) begin
        b_rptr_next = b_rptr + (r_en & !empty);
        // Convert binary to Gray code for crossing domains
        g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            b_rptr <= 0;
            g_rptr <= 0;
        end else begin
            b_rptr <= b_rptr_next;
            g_rptr <= g_rptr_next;
        end
    end

    // Improved empty condition logic
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            empty <= 1;
        else
            empty <= (g_wptr_sync == g_rptr_next) && (b_rptr != b_rptr_next || g_wptr_sync != g_rptr);
    end
endmodule

// FIFO Memory
module fifo_mem #(parameter DEPTH=8, DATA_WIDTH=8, PTR_WIDTH=3) (
    input wclk, w_en, rclk, r_en,
    input [PTR_WIDTH-1:0] b_wptr, b_rptr,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];

    always @(posedge wclk) begin
        if (w_en) begin
            fifo[b_wptr] <= data_in;
        end
    end

    always @(posedge rclk) begin
        if (r_en) begin
            data_out <= fifo[b_rptr];
        end
    end
endmodule

// Synchronizer Module for CDC
module synchronizer #(parameter WIDTH=3) (
    input clk,
    input rst_n,
    input [WIDTH:0] async_in,
    output reg [WIDTH:0] sync_out
);
    reg [WIDTH:0] sync_stage1, sync_stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_stage1 <= 0;
            sync_stage2 <= 0;
            sync_out <= 0;
        end else begin
            sync_stage1 <= async_in;
            sync_stage2 <= sync_stage1;
            sync_out <= sync_stage2;  // 2-stage synchronizer
        end
    end
endmodule

// Top Module
module fifo_top #(parameter DEPTH=8, DATA_WIDTH=8, PTR_WIDTH=3) (
    input wclk, wrst_n, w_en,
    input rclk, rrst_n, r_en,
    input [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output full, empty
);

    wire [PTR_WIDTH:0] b_wptr, g_wptr, b_rptr, g_rptr;
    wire [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;

    // Write pointer handler instance
    wptr_handler #(PTR_WIDTH) wptr_inst (
        .wclk(wclk),
        .wrst_n(wrst_n),
        .w_en(w_en),
        .g_rptr_sync(g_rptr_sync),
        .b_wptr(b_wptr),
        .g_wptr(g_wptr),
        .full(full)
    );

    // Read pointer handler instance
    rptr_handler #(PTR_WIDTH) rptr_inst (
        .rclk(rclk),
        .rrst_n(rrst_n),
        .r_en(r_en),
        .g_wptr_sync(g_wptr_sync),
        .b_rptr(b_rptr),
        .g_rptr(g_rptr),
        .empty(empty)
    );

    // FIFO memory instance
    fifo_mem #(DEPTH, DATA_WIDTH, PTR_WIDTH) fifo_inst (
        .wclk(wclk),
        .w_en(w_en),
        .rclk(rclk),
        .r_en(r_en),
        .b_wptr(b_wptr[PTR_WIDTH-1:0]),
        .b_rptr(b_rptr[PTR_WIDTH-1:0]),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Synchronizer for pointer crossing
    synchronizer #(PTR_WIDTH) sync_wptr (
        .clk(rclk),
        .rst_n(rrst_n),
        .async_in(g_wptr),
        .sync_out(g_wptr_sync)
    );

    synchronizer #(PTR_WIDTH) sync_rptr (
        .clk(wclk),
        .rst_n(wrst_n),
        .async_in(g_rptr),
        .sync_out(g_rptr_sync)
    );
endmodule
