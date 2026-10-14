`default_nettype wire

module reg_file (
    input  logic        clk,
    input  logic        rst_n,

    // Parallel Load (Decode): R0-R2 <- load_u.{x,y,z}, R3-R5 <- load_v.{x,y,z}
    input  logic                   load,
    input  tinytracer_pkg::vec3_t  load_u,
    input  tinytracer_pkg::vec3_t  load_v,

    // Macro-op Result (Decode): {R2, R1, R0}
    output tinytracer_pkg::vec3_t  result,

    // Write Port (FU Control)
    input  logic            wen,
    input  logic [2:0]      waddr,
    input  logic [tinytracer_pkg::WLEN-1:0] wdata,

    // Read Ports (FU Control)
    input  logic [2:0]      raddr1,
    output logic [tinytracer_pkg::WLEN-1:0] rdata1,
    input  logic [2:0]      raddr2,
    output logic [tinytracer_pkg::WLEN-1:0] rdata2
);
// Number of register cells (make cell count explicit for reviewers/synthesis)
localparam int N_REGS = 8;

// Two parallel read ports (raddr1/rdata1 and raddr2/rdata2) read from the
// same single `regs` storage. This does NOT duplicate storage — both ports
// access the same N_REGS-entry array in parallel.
logic [(tinytracer_pkg::WLEN-1) : 0] regs [N_REGS-1 : 0]; 
logic [1:0] load_cycle;

logic wen0;
logic [2:0] waddr0;
logic [tinytracer_pkg::WLEN-1:0] wdata0;

logic wen1;
logic [2:0] waddr1;
logic [tinytracer_pkg::WLEN-1:0] wdata1;

always_comb begin
    wen0 = load | wen;
    wen1 = load;

    waddr0 = load ? load_cycle : waddr;
    waddr1 = {1'b0,load_cycle} + 3'h3;

    if (load) begin
        case (load_cycle)
            2'b00: begin
                wdata0 = load_u.x;
                wdata1 = load_v.x;
            end
            2'b01: begin
                wdata0 = load_u.y;
                wdata1 = load_v.y;
            end
            2'b10: begin
                wdata0 = load_u.z;
                wdata1 = load_v.z;
            end
            default: begin
                wdata0 = wdata;
                wdata1 = load_v.x;
            end
        endcase
    end else begin
        wdata0 = wdata;
        wdata1 = load_v.x;
    end
end

always_ff @(posedge clk) begin 
    if (!rst_n) begin 
        // Reset all registers to 0
        for (integer i = 0; i < N_REGS; i++) begin
            regs[i] <= '0; 
        end
        load_cycle <= '0;
    end else begin 
        if (load) begin 
            load_cycle <= load_cycle[1] ? 2'b00 : load_cycle + 2'b01;
        end 
        if (wen0) begin 
            regs[waddr0] <= wdata0;
        end
        if (wen1) begin
            regs[waddr1] <= wdata1;
        end
    end 
end 

always_comb begin 
    // Outputs 
    rdata1 = regs[raddr1]; 
    rdata2 = regs[raddr2]; 
    result.x = regs[0]; 
    result.y = regs[1]; 
    result.z = regs[2]; 
end 

endmodule
