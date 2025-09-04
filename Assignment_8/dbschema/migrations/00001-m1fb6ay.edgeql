CREATE MIGRATION m1fb6ayxtgxoqcff5h6anfa66276z7yl6tklsjzys6a6sv2dilgypq
    ONTO initial
{
  CREATE TYPE default::Business {
      CREATE PROPERTY ID: std::str;
      CREATE CONSTRAINT std::exclusive ON (.ID);
      CREATE PROPERTY alias: std::str;
      CREATE PROPERTY coordinates: tuple<latitude: std::float32, longitude: std::float32>;
      CREATE PROPERTY name: std::str;
      CREATE PROPERTY rating: std::float32;
      CREATE PROPERTY review_count: std::int32;
  };
  CREATE TYPE default::StreetAddress {
      CREATE PROPERTY coordinates: tuple<latitude: std::float32, longitude: std::float32>;
      CREATE CONSTRAINT std::exclusive ON (.coordinates);
      CREATE PROPERTY address1: std::str;
      CREATE PROPERTY address2: std::str;
      CREATE PROPERTY address3: std::str;
  };
  ALTER TYPE default::Business {
      CREATE LINK has_address: default::StreetAddress;
  };
  ALTER TYPE default::StreetAddress {
      CREATE LINK has_business := (.<has_address[IS default::Business]);
  };
  CREATE TYPE default::Review {
      CREATE LINK reviews_business: default::Business;
      CREATE PROPERTY rating: std::float32;
      CREATE PROPERTY review_id: std::str;
      CREATE PROPERTY text: std::str;
      CREATE PROPERTY time_created: std::str;
  };
  ALTER TYPE default::Business {
      CREATE MULTI LINK has_reviews := (.<reviews_business[IS default::Review]);
  };
  CREATE TYPE default::Category {
      CREATE PROPERTY name: std::str;
      CREATE CONSTRAINT std::exclusive ON (.name);
  };
  ALTER TYPE default::Business {
      CREATE MULTI LINK in_category: default::Category;
  };
  ALTER TYPE default::Category {
      CREATE LINK has_business := (.<in_category[IS default::Business]);
  };
  CREATE TYPE default::CommunityArea {
      CREATE PROPERTY name: std::str;
  };
  ALTER TYPE default::Business {
      CREATE LINK in_communityArea: default::CommunityArea;
  };
  ALTER TYPE default::CommunityArea {
      CREATE MULTI LINK has_businesses := (.<in_communityArea[IS default::Business]);
  };
  CREATE TYPE default::City {
      CREATE PROPERTY name: std::str;
  };
  CREATE TYPE default::State {
      CREATE PROPERTY name: std::str;
  };
  ALTER TYPE default::City {
      CREATE LINK in_state: default::State;
      CREATE CONSTRAINT std::exclusive ON ((.name, .in_state));
  };
  ALTER TYPE default::CommunityArea {
      CREATE LINK in_city: default::City;
      CREATE CONSTRAINT std::exclusive ON ((.name, .in_city));
  };
  ALTER TYPE default::City {
      CREATE MULTI LINK has_communityAreas := (.<in_city[IS default::CommunityArea]);
  };
  CREATE TYPE default::ZipCode {
      CREATE LINK in_city: default::City;
      CREATE MULTI LINK in_communityArea: default::CommunityArea;
      CREATE PROPERTY digits: std::str;
      CREATE CONSTRAINT std::exclusive ON (.digits);
  };
  ALTER TYPE default::City {
      CREATE MULTI LINK has_zipCodes := (.<in_city[IS default::ZipCode]);
  };
  ALTER TYPE default::State {
      CREATE MULTI LINK has_cities := (.<in_state[IS default::City]);
  };
  ALTER TYPE default::CommunityArea {
      CREATE LINK has_zipcodes := (.<in_communityArea[IS default::ZipCode]);
  };
  CREATE TYPE default::Country {
      CREATE PROPERTY name: std::str;
      CREATE CONSTRAINT std::exclusive ON (.name);
  };
  ALTER TYPE default::State {
      CREATE LINK in_country: default::Country;
      CREATE CONSTRAINT std::exclusive ON ((.name, .in_country));
  };
  ALTER TYPE default::Country {
      CREATE MULTI LINK has_states := (.<in_country[IS default::State]);
  };
  CREATE TYPE default::User {
      CREATE PROPERTY user_id: std::str;
      CREATE CONSTRAINT std::exclusive ON (.user_id);
  };
  ALTER TYPE default::Review {
      CREATE LINK written_by: default::User;
  };
  ALTER TYPE default::User {
      CREATE MULTI LINK reviews := (.<written_by[IS default::Review]);
  };
  ALTER TYPE default::StreetAddress {
      CREATE LINK in_zipcode: default::ZipCode;
  };
  ALTER TYPE default::ZipCode {
      CREATE MULTI LINK has_streetAddresses := (.<in_zipcode[IS default::StreetAddress]);
  };
};
