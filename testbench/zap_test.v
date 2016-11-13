`include "config.vh"

module zap_test;

parameter RAM_SIZE  = 8192; // Bytes
parameter PHY_REGS  = 64;
parameter ALU_OPS   = 32;
parameter SHIFT_OPS = 5;
parameter ARCH_REGS = 32;

parameter START = 4992;
parameter COUNT = 120;

// Clock and reset.
reg              i_clk;                  // ZAP clock.        
reg              i_clk_2x;
reg              i_reset;                // Active high synchronous reset.
                
// From I-cache.
wire [31:0]       i_instruction;          // A 32-bit ZAP instruction.
wire             i_valid;                // Instruction valid.
wire             i_instr_abort;          // Instruction abort fault.


// Memory access.
wire             o_read_en;              // Memory load
wire             o_write_en;             // Memory store.
wire[31:0]       o_address;              // Memory address.

`ifdef COPROC_IF_EN

//Coproc wires.
wire                             o_copro_dav;
wire  [31:0]                     o_copro_word;

// Instr stall from CPU to RAM.
wire instr_stall;

`endif

// User view.
wire             o_mem_translate;

// Memory stall.
wire             i_data_stall;

// Memory abort.
wire             i_data_abort;

// Memory read data.
wire [31:0]      i_rd_data;

// Memory write data.
wire [31:0]      o_wr_data;

// Interrupts.
reg              i_fiq;                  // FIQ signal.
reg              i_irq;                  // IRQ signal.

// Program counter.
wire[31:0]      o_pc;                   // Program counter.

wire [31:0]      o_cpsr;                 // CPSR

`ifdef COPROC_IF_EN

reg             i_copro_reg_en;
reg [5:0]       i_copro_reg_wr_index;
reg [5:0]       i_copro_reg_rd_index;
reg [31:0]      i_copro_reg_wr_data;
wire [31:0]     o_copro_reg_rd_data;

`endif

wire [3:0] o_ben;

`ifdef COPROC_IF_EN

initial
begin
        i_copro_reg_en          = 0;
        i_copro_reg_wr_index    = 16;
        i_copro_reg_rd_index    = 16;
        i_copro_reg_wr_data     = 0;
end

`endif

`include "cc.vh"

// Testing interrupts.
`ifdef IRQ_EN
always @ (negedge i_clk)
        i_irq = $random;
`endif


// Processor core.
zap_top 
u_zap_top 
(
        .i_clk(i_clk),
        .i_clk_2x(i_clk_2x),
        .i_reset(i_reset),
        .i_instruction(i_instruction),
        .i_valid(i_valid),
        .i_instr_abort(i_instr_abort),
        .o_read_en(o_read_en),
        .o_write_en(o_write_en),
        .o_address(o_address),
        .o_mem_translate(o_mem_translate),
        .o_ben(o_ben),
        .i_data_stall(i_data_stall),
        .i_data_abort(i_data_abort),
        .i_rd_data(i_rd_data),
        .o_wr_data(o_wr_data),
        .i_fiq(i_fiq),
        .i_irq(i_irq),
        .o_pc(o_pc),

        `ifdef COPROC_IF_EN
        .i_copro_done (1'd1),           // Assume coprocessor completes its task.
        .o_copro_dav  (o_copro_dav),
        .o_copro_word (o_copro_word),

        .i_copro_reg_en(i_copro_reg_en),
        .i_copro_reg_wr_index(i_copro_reg_wr_index),
        .i_copro_reg_rd_index(i_copro_reg_rd_index),
        .i_copro_reg_wr_data(i_copro_reg_wr_data),
        .o_copro_reg_rd_data(o_copro_reg_rd_data),
        `endif

        .o_cpsr(o_cpsr),
        .o_instr_stall(instr_stall),

        .o_pc_nxt(),
        .o_address_nxt()
);

ram
#(
        .SIZE_IN_BYTES(RAM_SIZE)
)
u_ram
(
        .i_clk(i_clk),
        .i_instr_stall(instr_stall),
        .i_daddress(o_address),
        .i_iaddress(o_pc),
        .o_ddata(i_rd_data),
        .o_idata(i_instruction),
        .i_ben(o_ben),
        .i_ddata(o_wr_data),
        .i_wr_en(o_write_en),
        .i_cpsr(o_cpsr),
        .o_data_stall(i_data_stall),
        .o_code_hit(i_valid),
        .o_code_abort(i_instr_abort),
        .o_data_abort(i_data_abort)
);

initial i_clk = 0;
always #10 i_clk = !i_clk;

initial
begin
        i_clk_2x = 0;
        #5;
        forever #5 i_clk_2x = !i_clk_2x;        
end

integer i;

initial
begin
        i_irq = 0;
        i_fiq = 0;

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("INITIAL :: mem[%d] = %x", i, {u_ram.ram[(i/4)]});
        end

        $dumpfile(`VCD_FILE_PATH);
        $dumpvars;

        $display("Started!");

        i_reset = 1;
        @(negedge i_clk);
        i_reset = 0;

        repeat(`MAX_CLOCK_CYCLES) @(negedge i_clk);

        for(i=START;i<START+COUNT;i=i+4)
        begin
                $display("mem[%d] = %x", i, {u_ram.ram[(i/4)]});
        end

        $finish;
end

endmodule
