require "rubygems"
require "sinatra"
require "pry"

use Rack::Session::Cookie, :key => "rack.session",
                           :path => "/",
                           :secret => "pizzasauce" 

BLACKJACK = 21
DEALER_HIT = 17
INITIAL_POT = 500

# Helper functions
helpers do

  # Given a hand e.g. [["H", "3"], ["C", "A"]], return its total value.
  def total_value(hand)
    sum = 0
    count_of_aces = 0
    hand.each do |card|
      if ["J", "Q", "K"].include?(card[1])
        sum += 10
      elsif card[1] == "A"
        sum += 11
        count_of_aces += 1
      else
        sum += card[1].to_i
      end
    end
    if sum > BLACKJACK && count_of_aces >= 1
      sum = sum - 10
    end
    sum
  end

  # Takes the code of a suit i.e. "H", "D", "C", "S", and converts it to full word.
  def to_suit(code)
    case code
    when "H"
      "hearts"
    when "D"
      "diamonds"
    when "C"
      "clubs"
    when "S"
      "spades"
    end
  end

  # Takes the code of a value, e.g. "A", "Q", "K" and converts it to full word.
  def to_val(code)
    case code
    when "A"
      "ace"
    when "J"
      "jack"
    when "Q"
      "queen"
    when "K"
      "king"
    end
  end

  # Takes a card e.g. ["H", "3"] and converts it to its corresponding image tag.
  def to_image(card)
    if ["A", "J", "Q", "K"].include?(card[1])
      val = to_val(card[1])
    else
      val = card[1]
    end
    suit = to_suit(card[0])
    file_name = suit + "_" + val
    return '<img src="/images/cards/' + file_name + '.jpg" border="0" class="cards">'
  end

  # Announces winner with a message
  def winner!(msg)
    @play_again = true
    session[:cash] += session[:bet_amt]
    @winner = "<strong>#{session[:username]} has won.</strong> " + msg + " #{session[:username]} now has $#{session[:cash]}." 
    erb :game
  end

  # Announces loser with a message
  def loser!(msg)
    @play_again = true
    session[:cash] -= session[:bet_amt]
    @loser = "<strong>#{session[:username]} has lost.</strong> " + msg + " #{session[:username]} now has $#{session[:cash]}."
    erb :game
  end

  def tie!(msg)
    @play_again = true
    @winner = msg + " #{session[:username]} will retain his $#{session[:bet_amt]}."
    erb :game
  end

end

before do
  @show_hit_or_stay_buttons = true
end

# Main page
get "/" do
  # If username isn"t set, redirect them to set their name
  if !session[:username]
      redirect "/new_player"
  # Else load their game
  else
    redirect "/game"
  end
end

# Erase user data and starts user over.
get "/new_player" do
  session.clear
  erb :new_player
end

# Sets new player.
post "/new_player" do
  if params[:username].empty?
    @error = "Please enter a name."
    halt erb(:new_player)
  end
  session[:username] = params[:username]
  session[:cash] = INITIAL_POT
  redirect "/bet"
end

get "/bet" do
  # Clear bet amount.
  session[:bet_amt] = nil
  # If user has run out of money, redirect to game over.
  if session[:cash] <= 0
    redirect '/game_over'
  end
  erb :bet
end

# Starts a new bet.
post "/bet" do
  # Clear off previous game data.
  session.delete(:deck)
  session.delete(:mycards)
  session.delete(:dealercards)
  session.delete(:turn)
  # Check if bet amount is between 0 and the amount of cash user has.
  if params[:bet_amt].nil? || params[:bet_amt].to_i == 0 || params[:bet_amt].to_i < 0 || params[:bet_amt].to_i > session[:cash]
    @error = "Please input a valid amount from $1 to $#{session[:cash]}."
    halt erb(:bet)
  else
    session[:bet_amt] = params[:bet_amt].to_i
    session[:turn] = "player"
    redirect "/game"
  end
end

# Main game
get "/game" do
  # Redirect to betting page if bet isn"t made yet.
  if !session[:bet_amt]
    redirect "/bet"
  end

  # If deck hasn"t been created in session yet.
  if !session[:deck]
    # Create new deck.
    suits = ["H", "D", "S", "C"]
    cards = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
    session[:deck] = suits.product(cards).shuffle!

    # Deals player and computer both 2 cards.
    session[:mycards] = []
    session[:dealercards] = []

    session[:mycards] << session[:deck].pop
    session[:mycards] << session[:deck].pop
    session[:dealercards] << session[:deck].pop
    session[:dealercards] << session[:deck].pop
  end

  player_total = total_value(session[:mycards])
  dealer_total = total_value(session[:dealercards])

  if player_total == BLACKJACK
    winner!("#{session[:username]} has hit blackjack!")
    @show_hit_or_stay_buttons = false
  elsif dealer_total == BLACKJACK
    loser!("It looks like dealer has hit blackjack.")
    @show_hit_or_stay_buttons = false
  end

  erb :game
end

# If player HITs.
post "/game/player/hit" do
  # Deal new card.
  session[:mycards] << session[:deck].pop

  player_total = total_value(session[:mycards])

  # If player hits blackjack.
  if player_total == BLACKJACK
    winner!("#{session[:username]} has hit blackjack!")
    @show_hit_or_stay_buttons = false
  # If player has busted.
  elsif player_total > BLACKJACK
    loser!("It looks like #{session[:username]} busted at #{total_value(session[:mycards])}.")
    @show_hit_or_stay_buttons = false
  else
  end
  erb :game, layout: false
end

# If player STAYs.
post "/game/player/stay" do
  redirect "/game/dealer"
end

get "/game/dealer" do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  dealer_total = total_value(session[:dealercards])
  # If dealer hits blackjack.
  if dealer_total == BLACKJACK
    loser!("It looks like dealer has hit blackjack.")
  # If dealer has busted.
  elsif dealer_total > BLACKJACK
    winner!("Dealer has busted!")
  # If dealer has less than 17
  elsif dealer_total < DEALER_HIT
    @show_dealer_btn = true
  # If dealer has 17 or more
  else
    redirect "/game/compare"
  end

  erb :game, layout: false

end

# When dealer HITs.
post "/game/dealer/hit" do
  # Deal new card.
  session[:dealercards] << session[:deck].pop
  @show_hit_or_stay_buttons = false
  redirect "/game/dealer"
end

# Compare player and dealer"s value
get "/game/compare" do
  player_total = total_value(session[:mycards])
  dealer_total = total_value(session[:dealercards])
  # If it's a tie
  if player_total == dealer_total
    tie!("It's a tie.")
  # If dealer has won.
  elsif dealer_total > player_total
    loser!("#{session[:username]} stayed at #{total_value(session[:mycards])} and the dealer stayed at #{total_value(session[:dealercards])}.")
  # If player has won.
  else 
    winner!("#{session[:username]} stayed at #{total_value(session[:mycards])} and the dealer stayed at #{total_value(session[:dealercards])}.")
  end

  @show_hit_or_stay_buttons = false
  erb :game, layout: false
end

# Asks if user wants to play again
post "/play_again" do
  # If user clicked Yes
  if params[:yes]
    if session[:cash] <= 0
      redirect "/game_over"
    else
      redirect "/bet"
    end
  # If user clicked No
  else
    redirect "/game_over"
  end
end

# When user quits game.
get "/game_over" do
  if session[:cash] <= 0
    @broke = true
  end
  erb :game_over
end