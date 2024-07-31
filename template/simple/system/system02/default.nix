_: {
  keys = [ "age13cwyduwmygwryyq28tggpwx6eupja4ad8mdxyfcla9yncvuzya6sgd9qe6" ];
  secretFiles = {
    extra = ./extraSecrets.sops.yaml;

    user = {
      file = ./user.sops.yaml;
      keys = [
        {
          key = "age10dv7rs9w9u42evv26syqspnfd6pnsfvdqlz88uvfwzgvwzju95tsafw2y9";
          desc = "user key";
        }

      ];
    };
  };
}
