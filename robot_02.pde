
#define DEBUG 0

#define MOTOR_1A 2
#define MOTOR_1B 3
#define MOTOR_2A 4
#define MOTOR_2B 5

#define IR_LED 7
#define GREEN_LED 6
#define RED_LED 8
#define YELLOW_LED 9
#define SONAR_PIN 0

#define MAX 128
#define MICRO_STEP 10

#define IDLE_PULSE 10000
#define START_PULSE 4000
#define REPEAT_PULSE 2000
#define ONE_PULSE 1500
#define ZERO_PULSE 400

#define RIGHT 1
#define LEFT -1

int checkDistance = 0;
int lastBest = RIGHT;
int lastBestDist = 0;

unsigned long pulses[MAX];
unsigned long code = 0;
int red_led_state = 0;

void forward()
{
  digitalWrite(MOTOR_1A, LOW);
  digitalWrite(MOTOR_1B, HIGH);
  digitalWrite(MOTOR_2A, LOW);
  digitalWrite(MOTOR_2B, HIGH);
  checkDistance = 1;
}

void backward()
{
  digitalWrite(MOTOR_1A, HIGH);
  digitalWrite(MOTOR_1B, LOW);
  digitalWrite(MOTOR_2A, HIGH);
  digitalWrite(MOTOR_2B, LOW);
  checkDistance = 0;
}

void right()
{
  digitalWrite(MOTOR_1A, LOW);
  digitalWrite(MOTOR_1B, HIGH);
  digitalWrite(MOTOR_2A, HIGH);
  digitalWrite(MOTOR_2B, LOW);
  checkDistance = 0;
}

void left()
{
  digitalWrite(MOTOR_1A, HIGH);
  digitalWrite(MOTOR_1B, LOW);
  digitalWrite(MOTOR_2A, LOW);
  digitalWrite(MOTOR_2B, HIGH);
  checkDistance = 0;
}

void stop()
{
  digitalWrite(MOTOR_1A, LOW);
  digitalWrite(MOTOR_1B, LOW);
  digitalWrite(MOTOR_2A, LOW);
  digitalWrite(MOTOR_2B, LOW);
  checkDistance = 0;
}

void toggleLED()
{
  red_led_state ^= 1;
  if(red_led_state)
    digitalWrite(RED_LED, HIGH);
  else
    digitalWrite(RED_LED, LOW);
}

void setup()
{
  pinMode(MOTOR_1A, OUTPUT);
  pinMode(MOTOR_1B, OUTPUT);
  pinMode(MOTOR_2A, OUTPUT);
  pinMode(MOTOR_2B, OUTPUT);
  
  pinMode(IR_LED, INPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  
  digitalWrite(RED_LED, LOW);
  digitalWrite(GREEN_LED, HIGH);
  digitalWrite(YELLOW_LED, LOW);
  
  // For debug
  if(DEBUG)
    Serial.begin(115200);
}

void loop()
{   
  // Sonar
  int distance = analogRead(0);
  if( distance < 15 )
    {
      digitalWrite(13, HIGH);
    }
    else
    {
      digitalWrite(13, LOW);
    }
  
  if( checkDistance && distance < 15) 
  {
    digitalWrite(GREEN_LED, LOW);
      
    stop();
    backward();
    delay(500);
    stop();
      
    digitalWrite(GREEN_LED, HIGH);
  }
  
  // The IR receiver output is set HIGH until a signal comes in ...
  if( digitalRead(IR_LED) == LOW)
  {
    // No command can be received while the green LED is off
    digitalWrite(GREEN_LED, LOW);
    
    //Start receiving data ...
    int count = 0; // Number of pulses
    int exit = 0;
    while(!exit)
    {
      while( digitalRead(IR_LED) == LOW )
        delayMicroseconds(MICRO_STEP);

      // Store the time when the pulse begin      
      unsigned long start = micros();

      int max_high = 0;
      while( digitalRead(IR_LED) == HIGH )
      {
        delayMicroseconds(MICRO_STEP);
        
        max_high += MICRO_STEP;
        if( max_high > IDLE_PULSE )
        {
          exit = 1;
          break;
        }
      }
        
      unsigned long duration = micros() - start;
      pulses[count++] = duration;
    }
    
    // Build code from pulses
    int repetitions = 0;    
    int bit_position = 0;
    unsigned long bit = 2147483648; // 10000000000000000000000000000000 in binary
    unsigned long new_code = 0;
    
    for(int i=0; i<count; i++)
    {
      if(pulses[i] > IDLE_PULSE)
      {
        // Ignore very long pulses
        continue;
      }
      else if(pulses[i] > START_PULSE)
      {
        // Start pulse received ... start counting bits
        new_code = 0;
        bit_position = 0;
      }
      else if(pulses[i] > REPEAT_PULSE)
      {
        // Repetition command ... no bit pulses here.
        repetitions++;
      }
      else if(pulses[i] > ONE_PULSE)
      {
        // Receives "1"
        if(DEBUG)
          Serial.print("1");
          
        new_code |= bit >> bit_position++;
      }
      else if(pulses[i] > ZERO_PULSE)
      {
        // Receives "0"
        if(DEBUG)
          Serial.print("0");
          
        bit_position++;        
      }
    }
    
    if( new_code )
    {
      // This was not a repeat command
      code = new_code;
    }
    
    // Display the code received and number of bits or, repetitions.
    if(DEBUG)
    {
      if( !new_code)
      {
        Serial.print("                                ");
      }
    
      Serial.print("     ");
      Serial.print(bit_position, DEC);
      Serial.print(" bits ");
      Serial.print(repetitions, DEC);
      Serial.print(" repetition(s) code = ");
      Serial.print(code, BIN);
      Serial.print(" (");
      Serial.print(code, DEC);
      Serial.print(")");
    
      Serial.println("");
    }
    
    
    // Flashes the yellow LED for every repeat commands
    if( repetitions > 0 )
    {
      for( int i=0; i<repetitions; i++)
      {
        digitalWrite(YELLOW_LED, HIGH);
        delay(50);
        digitalWrite(YELLOW_LED, LOW);
        delay(50);
      }
    }
    
    // POWER    279939191
    // UP       279933071
    // DOWN     279949391
    // RIGHT    279937151
    // LEFT     279912671
    
    // Toggle red LED when power button command is received
    if(code == 279939191 && bit_position > 0) 
    {       
      toggleLED();        
      stop();
    }
    
    // UP
    if( code == 279933071 && bit_position > 0)
    {        
      toggleLED();        
      forward();
    }
    
    // DOWN
    if( code == 279949391 && bit_position > 0)
    {        
      toggleLED();        
      backward();
    }
    
    // LEFT
    if( code == 279912671 && bit_position > 0)
    {        
      toggleLED();        
      left();
    }
    
    // RIGHT
    if( code == 279937151 && bit_position > 0)
    {        
       toggleLED();        
       right();
    }
    
    // Ready to process an other command
    digitalWrite(GREEN_LED, HIGH);
  }
}

