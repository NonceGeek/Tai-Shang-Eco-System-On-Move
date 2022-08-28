module XUSDTAddr::XUSDT {
     use StarcoinFramework::Token;
     use StarcoinFramework::Account;
     use StarcoinFramework::Signer;

 
     struct XUSDT has copy, drop, store {
          
      }
   

     public(script) fun init(admin: signer) {
         let admin_address = Signer::address_of(&admin);
         assert!(admin_address== @XUSDTAddr,2);
         Token::register_token<XUSDT>(&admin, 3);
         Account::do_accept_token<XUSDT>(&admin);
   
        
     }

     public(script) fun mint(account: signer,receive:address, amount: u128) {
        let admin_address = Signer::address_of(&account);
        assert!(admin_address== @XUSDTAddr,1);
        if(!Account::is_accepts_token<XUSDT>(admin_address)){
            Account::do_accept_token<XUSDT>(&account);
        };
        
        let token = Token::mint<XUSDT>(&account, amount);
        Account::deposit<XUSDT>(receive, token);
     }
}
