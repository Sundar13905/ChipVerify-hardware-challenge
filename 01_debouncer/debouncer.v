module debouncer #(parameter CLK_FREQ_KHZ = 100) (
    input clk,
    input rst_n,
    input btn_in,
    output reg btn_out,
    output reg btn_pressed,
    output reg btn_released
);

    localparam DEBOUNCE_CYCLES = CLK_FREQ_KHZ * 5;

    reg [8:0] counter;

    always @(posedge clk) begin

        if (!rst_n) begin
            btn_out <= 1'b0;
            counter <= 9'd0;
        end

        else begin

            if (counter == 9'd511) begin
                counter <= 9'd0;
            end
            else if (btn_in == btn_out) begin
                counter <= 9'd0;
            end

            else if (counter == DEBOUNCE_CYCLES - 1) begin
                btn_out <= btn_in;
                counter <= 9'd511;
            end

            else begin
                counter <= counter + 1'b1;
            end
        end
    end
    always @(*) begin
        btn_pressed  = (counter == 9'd511) & btn_out;
        btn_released = (counter == 9'd511) & ~btn_out;
    end

endmodule
