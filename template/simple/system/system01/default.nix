_: {
  keys = [ "age1j2wjd2dxw0kw7jssnkfr9nmfqeqgr38qcdwh4fhkadnvnndd8cns6z9208" ];
  secretFiles = {
    extra = ./extraSecrets.sops.yaml;
    user = {
      file = ./user.sops.yaml;
      keys = [
        {
          key = "age10vttwn7ucjd92jp7mlkc7kam7g264wpxum0hkljulhgzv9la3atq4gef85";
          desc = "user key";
        }
      ];
    };
  };
}
