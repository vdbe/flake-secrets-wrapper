#!/usr/bin/env python3

from collections import defaultdict
from enum import Enum, unique
import argparse
import enum
import json
from typing import DefaultDict, final
import sys


class KeyType(Enum):
    GPG = 1
    AGE = 2


class KeyWeight(Enum):
    MASTER = 1
    SYSTEM = 2
    SECRET_FILE = 3

    def __lt__(self, other):
        return self.value < other.value


class Key:
    def __init__(
        self,
        weight: KeyWeight,
        type: KeyType,
        value: str,
        id=None,
        desc=None,
        context=None,
    ):
        self.weight = weight
        self.type = type
        self.value = value
        self.context = context
        self.id: None | str = id
        self.desc: list[str] = []
        self.id_fixed: None | bool = self.id is not None

        self.add_desc(desc)

    def add_desc(self, desc):
        if desc and desc not in self.desc:
            self.desc.append(desc)


class KeyCollection:
    def __init__(self):
        self.keys: list[Key] = []
        self.keys_by_value: dict[str, list[Key]] = DefaultDict(lambda: [])
        self.keys_by_id: dict[str, list[Key]] = DefaultDict(lambda: [])
        self.master_keys: list[Key] = []

    def add_key(self, key: Key):
        if not key.id:
            key.id = "_".join(key.context or ["unkown"])

        self.keys.append(key)
        self.keys_by_id[key.id].append(key)
        self.keys_by_value[key.value].append(key)

        if key.weight == KeyWeight.MASTER:
            self.master_keys.append(key)

    def sort(self):
        # Sort lists
        self.keys.sort(key=lambda k: k.weight)
        for keys in self.keys_by_id.values():
            keys.sort(key=lambda k: k.weight)
        for keys in self.keys_by_value.values():
            keys.sort(key=lambda k: k.weight)

    def merge(self):
        fixed_ids: set[str] = set()
        self.keys = list(dict.fromkeys(self.keys))

        # Check if there are no 2 keys with the same fixed id
        for id, keys in self.keys_by_id.items():
            fixed_keys = [fixed_key for fixed_key in keys if fixed_key.id_fixed]
            fixed_keys_value = [fixed_key.value for fixed_key in fixed_keys]

            unique_fixed_key_values = []
            for fixed_key_value in fixed_keys_value:
                if fixed_key_value not in unique_fixed_key_values:
                    unique_fixed_key_values.append(fixed_key_value)

            if len(unique_fixed_key_values) > 1:
                raise ValueError(
                    "Multiple keys with the same fixed id and diffrent values"
                )

            if len(unique_fixed_key_values) == 1:
                fixed_ids.add(id)

        # add number suffix to none fixed id's
        for id, keys in self.keys_by_id.items():
            unique_keys = list(dict.fromkeys(keys))
            if id in fixed_ids:
                # print(
                #     f"WARNING: collisions between fixed and generated id's for {id}",
                #     file=sys.stderr,
                # )
                pass
            keys_with_generated_ids = [
                fixed_key for fixed_key in unique_keys if not fixed_key.id_fixed
            ]

            if len(unique_keys) > 1:
                for i, key_with_generated_id in enumerate(keys_with_generated_ids):
                    if key_with_generated_id.id is not None:
                        key_with_generated_id.id += f"_{i + 1}"
                        key_with_generated_id.context.append(i + 1)
                    else:
                        raise ValueError("key should always have an id")
        self.sort()


class SecretFile:
    def __init__(self, path: str, keys=[]):
        self.path = path
        self.keys: list[Key] = keys

    def add_key(self, key):
        self.keys.append(key)

    def update_keys(self, key_collection: KeyCollection):
        final_keys: list[Key] = key_collection.master_keys.copy()
        to_be_updated_keys: list[Key] = []

        for key in self.keys:
            if key.id_fixed:
                final_keys.append(key)
            else:
                to_be_updated_keys.append(key)

        to_be_updated_key_values = set([k.value for k in to_be_updated_keys])
        for key_value in to_be_updated_key_values:
            final_keys.append(key_collection.keys_by_value[key_value][0])

        self.keys = final_keys


def str_to_key_type(key_type: str):
    match key_type:
        case "gpg":
            return KeyType.GPG
        case "age":
            return KeyType.AGE
        case _:
            raise ValueError("Unkown key type")


def print_yaml(
    used_keys: KeyCollection, secret_files: list[SecretFile], file=sys.stdout
):
    def indent(s: str, indent=0):
        return " " * (indent * 2) + s

    def p(s="", indentation=0, file=file):
        print(indent(s, indent=indentation), file=file)

    p("keys:")
    for key in used_keys.keys:
        p(f"- &{key.id} {key.value}", 1)

    p()
    p("creation_rules:")
    for secret_file in secret_files:
        regex = f"^({secret_file.path})$"
        p(f"- path_regex: {regex}", 1)
        p(f"key_groups:", 2)
        gpg_keys = [key for key in secret_file.keys if key.type == KeyType.GPG]
        age_keys = [key for key in secret_file.keys if key.type == KeyType.AGE]

        if len(gpg_keys):
            p("- pgp:", 3)
            for gpg_key in gpg_keys:
                p(f"- *{gpg_key.id}", 4)
        if len(age_keys):
            if len(gpg_keys):
                p("age:", 4)
            else:
                p("- age:", 3)
            for age_key in age_keys:
                p(f"- *{age_key.id}", 4)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "secrets_config",
        metavar="secrets-config",
        type=str,
        help="path of the secrts config",
    )
    parser.add_argument(
        "-o",
        "--out",
        type=str,
        help="path of the secrts config",
    )
    args = parser.parse_args()

    with open(args.secrets_config, "r") as file:
        secrets_config = json.load(file)

    keys = KeyCollection()
    secret_files: list[SecretFile] = []

    master_keys = secrets_config["masterKeys"]
    for master_key in master_keys:
        key_type = str_to_key_type(master_key["type"])

        key = Key(
            KeyWeight.MASTER,
            key_type,
            master_key["key"],
            desc=master_key["desc"],
            id=master_key["id"],
        )
        keys.add_key(key)

    hosts = secrets_config["hosts"]
    for host_name, host in hosts.items():
        for host_key in host["keys"]:
            key_type = str_to_key_type(host_key["type"])

            key = Key(
                KeyWeight.SYSTEM,
                key_type,
                host_key["key"],
                desc=host_key["desc"],
                context=[host_name],
            )
            keys.add_key(key)

        for _, sf in host["secretFiles"].items():
            secret_file_keys = []
            for k in sf["keys"]:
                key_type = str_to_key_type(k["type"])

                key = Key(
                    KeyWeight.SECRET_FILE,
                    key_type,
                    k["key"],
                    desc=k["desc"],
                    context=[host_name, "file"],
                )
                secret_file_keys.append(key)
                keys.add_key(key)

            secret_file = SecretFile(sf["file"], secret_file_keys)
            secret_files.append(secret_file)

    d_secret_files: dict[str, SecretFile] = {}
    for secret_file in secret_files:
        if secret_file.path in d_secret_files:
            d_secret_files[secret_file.path].keys.extend(secret_file.keys)
        else:
            d_secret_files[secret_file.path] = secret_file
    secret_files = list(d_secret_files.values())

    keys.sort()
    used_keys = KeyCollection()
    for secret_file in secret_files:
        secret_file.update_keys(keys)
        for key in secret_file.keys:
            used_keys.add_key(key)
    used_keys.merge()

    if args.out:
        with open(args.out, "w") as file:
            print_yaml(used_keys, secret_files, file=file)
    else:
        print_yaml(used_keys, secret_files)


if __name__ == "__main__":
    main()
