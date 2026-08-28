module traffic_light (
    input            clk, rst_n, emergency,
    output reg [1:0] ns_light,
    output reg [1:0] ew_light
);
    // Phases: 0=NS_GREEN(30), 1=NS_YELLOW(5), 2=EW_GREEN(30), 3=EW_YELLOW(5)
    // Light encoding: 2'b10=Green, 2'b01=Yellow, 2'b00=Red
    // Your implementation here
    localparam NS_GREEN  = 2'b00;
    localparam NS_YELLOW = 2'b01;
    localparam EW_GREEN  = 2'b10;
    localparam EW_YELLOW = 2'b11;

    
    
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [4:0] count;

    always@(posedge clk) begin 

        if(!rst_n) begin
            count <= 5'd0;
            current_state <= NS_GREEN;
        end
        else if(emergency) begin
            count <= 5'd0;
        end
        else begin 
            current_state <= next_state;
            if (next_state != current_state)
                count <= 5'd0;
            else 
            count <= count+1;
        end
    end

    always @(*)begin

        next_state = current_state;
        ns_light = 2'b00;
        ew_light = 2'b00;

        if (emergency) begin
            ns_light = 2'b00;
            ew_light = 2'b00;
        end
        else begin
            case(current_state)

            NS_GREEN: begin 

                ns_light = 2'b10;
                ew_light = 2'b00;
                if(count == 5'd30)begin 
                    next_state = NS_YELLOW;
                end
                else begin 
                    next_state = NS_GREEN;
                end
            end

            NS_YELLOW: begin 

                ns_light = 2'b01;
                ew_light = 2'b00;

                if(count == 5'd4)begin 
                    next_state = EW_GREEN;
                end
                else begin 
                    next_state = NS_YELLOW;
                end
            end

            EW_GREEN: begin 

                ns_light = 2'b00;
                ew_light = 2'b10;


                if(count == 5'd29)begin 
                    next_state = EW_YELLOW;
                end
                else begin 
                    next_state = EW_GREEN;
                end
            end

            EW_YELLOW: begin 

                ns_light = 2'b00;
                ew_light = 2'b01;

                if(count == 5'd4)begin 
                    next_state = NS_GREEN;
                end
                else begin 
                    next_state = EW_YELLOW;
                end
            end
            endcase
        end
    end



endmodule
