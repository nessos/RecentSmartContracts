pragma solidity ^0.5.0;

contract UserProfile {

    struct Profile { 
        bytes32 nickname;
        string avatarIpfsCID;   
        bytes32 firstname;
        bytes32 lastname;   
        uint contentProviderRatingTotalPoints;   
        uint contentConsumerRatingTotalPoints;     
        uint contentProviderVotes;
        uint contentConsumerVotes;
        string statusText;
        bool disabled;
    }
    
    // This creates an array with all profiles
    mapping (address => Profile) public users;

    
    mapping (address => mapping (address => uint)) public providerVotes;

    mapping (address => mapping (address => uint)) public consumerVotes;

    /**
     * Constructor function
     * Initializes RecentProfile contract
    */
    constructor() public {
    }

    function updateProfile(bytes32 nickname, string memory avatarIpfsCID, bytes32 firstname, bytes32 lastname, string memory statusText, bool disabled) public {        
        users[msg.sender].nickname = nickname;
        users[msg.sender].avatarIpfsCID = avatarIpfsCID;
        users[msg.sender].firstname = firstname;
        users[msg.sender].lastname = lastname;
        users[msg.sender].statusText = statusText;
        users[msg.sender].disabled = disabled;
    }

    /**
        * Rate Provider
    */
    function rateProvider(address user, uint rating) public {
        require(rating > 0 && rating < 500, "Rating should be greater than zero and lower than 500");
        if (providerVotes[msg.sender][user] == 0 ) {
            users[msg.sender].contentProviderRatingTotalPoints += rating;
            users[msg.sender].contentProviderVotes += 1;     
        } else {
            users[msg.sender].contentProviderRatingTotalPoints += rating;
            users[msg.sender].contentProviderRatingTotalPoints -= providerVotes[msg.sender][user];        
        }
        providerVotes[msg.sender][user] = rating;
    }

    /**
        * Rate Consumer
    */
    function rateConsumer(address user, uint rating) public {
        require(rating > 0 && rating < 500, "Rating should be greater than zero and lower than 500");
        if (consumerVotes[msg.sender][user] == 0 ) {
            users[msg.sender].contentConsumerRatingTotalPoints += rating;
            users[msg.sender].contentConsumerVotes += 1;     
        } else {
            users[msg.sender].contentConsumerRatingTotalPoints += rating;
            users[msg.sender].contentConsumerRatingTotalPoints -= consumerVotes[msg.sender][user];        
        }
        consumerVotes[msg.sender][user] = rating;
    }

    /**
        * Get user Rating
    */
    function getUserRating(address user) public view returns(uint providerRating, uint consumerRating) {
        uint contentConsumerRating = 0;
        uint contentProviderRating = 0;
        if (users[user].contentConsumerVotes > 0) {
            contentConsumerRating = users[user].contentConsumerRatingTotalPoints / users[user].contentConsumerVotes;
        }
        if (users[user].contentProviderVotes > 0) {
            contentProviderRating = users[user].contentProviderRatingTotalPoints / users[user].contentProviderVotes;
        }
        return (contentConsumerRating, contentProviderRating);
    }

}
