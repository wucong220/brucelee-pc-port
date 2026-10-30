from pathlib import Path
import hashlib
import struct
import sys
from unittest.mock import patch
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import native_animation_blending as native
from native_hierarchy_links import HierarchyLinkError


class TestNativeAnimationBlending(unittest.TestCase):
    def _fixture(self) -> bytearray:
        size = max(
            max(native._WORDS),
            max(address + 12 for address in native._PLT),
            max(address + len(value) for address, value in native._STRINGS.items()),
        ) + 4
        fixture = bytearray(size)
        for address, word in native._WORDS.items():
            struct.pack_into("<I", fixture, address, word)
        for address, (_, _, words) in native._PLT.items():
            struct.pack_into("<III", fixture, address, *words)
        for address, value in native._STRINGS.items():
            fixture[address : address + len(value)] = value
        return fixture

    def _symbols(self) -> dict[int, str]:
        return {
            relocation: name
            for relocation, name, _ in native._PLT.values()
        }

    def _dynamic_relocations(self) -> dict[int, str]:
        return dict(native._DYN_RELOCATIONS)

    def _patches(self, fixture: bytearray):
        return (
            patch.object(
                native,
                "file_offset",
                side_effect=lambda elf, address: address,
            ),
            patch.object(native, "_dynamic_symbols", return_value=self._symbols()),
            patch.object(
                native,
                "_dynamic_relocation_symbols",
                return_value=self._dynamic_relocations(),
            ),
            patch.object(native, "_SHA256", hashlib.sha256(fixture).hexdigest()),
        )

    def test_unknown_binary_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            native.verify_bytes(b"not the recorded ELF")

    def test_each_recorded_instruction_is_required(self):
        fixture = self._fixture()
        offset_patch, symbols_patch, relocations_patch, hash_patch = self._patches(
            fixture
        )
        with offset_patch, symbols_patch, relocations_patch, hash_patch:
            native.verify_bytes(fixture)
            for address in native._WORDS:
                with self.subTest(address=hex(address)):
                    altered = bytearray(fixture)
                    altered[address] ^= 1
                    with patch.object(
                        native,
                        "_SHA256",
                        hashlib.sha256(altered).hexdigest(),
                    ):
                        with self.assertRaisesRegex(
                            HierarchyLinkError,
                            f"instruction at 0x{address:08x}",
                        ):
                            native.verify_bytes(altered)

    def test_property_strings_are_required(self):
        fixture = self._fixture()
        offset_patch, symbols_patch, relocations_patch, hash_patch = self._patches(
            fixture
        )
        with offset_patch, symbols_patch, relocations_patch, hash_patch:
            native.verify_bytes(fixture)
            for address, value in native._STRINGS.items():
                with self.subTest(address=hex(address)):
                    altered = bytearray(fixture)
                    altered[address] ^= 1
                    with patch.object(
                        native,
                        "_SHA256",
                        hashlib.sha256(altered).hexdigest(),
                    ):
                        with self.assertRaisesRegex(
                            HierarchyLinkError,
                            f"property string at 0x{address:08x}",
                        ):
                            native.verify_bytes(altered)

    def test_each_plt_stub_and_target_is_required(self):
        fixture = self._fixture()
        offset_patch, symbols_patch, relocations_patch, hash_patch = self._patches(
            fixture
        )
        with offset_patch, symbols_patch, relocations_patch, hash_patch:
            for address in native._PLT:
                with self.subTest(address=hex(address)):
                    altered = bytearray(fixture)
                    altered[address] ^= 1
                    with patch.object(
                        native,
                        "_SHA256",
                        hashlib.sha256(altered).hexdigest(),
                    ):
                        with self.assertRaisesRegex(
                            HierarchyLinkError,
                            f"PLT or relocation mismatch at 0x{address:08x}",
                        ):
                            native.verify_bytes(altered)

    def test_relocation_names_cannot_be_swapped(self):
        fixture = self._fixture()
        offset_patch, _, relocations_patch, hash_patch = self._patches(fixture)
        first_address = next(iter(native._PLT))
        entries = list(native._PLT.values())
        symbols = self._symbols()
        symbols[entries[0][0]], symbols[entries[1][0]] = (
            entries[1][1],
            entries[0][1],
        )
        with offset_patch, relocations_patch, hash_patch, patch.object(
            native,
            "_dynamic_symbols",
            return_value=symbols,
        ):
            with self.assertRaisesRegex(
                HierarchyLinkError,
                rf"PLT or relocation mismatch at 0x{first_address:08x}",
            ):
                native.verify_bytes(fixture)

    def test_dynamic_vtable_relocations_are_required(self):
        fixture = self._fixture()
        offset_patch, symbols_patch, _, hash_patch = self._patches(fixture)
        for address in native._DYN_RELOCATIONS:
            with self.subTest(address=hex(address)):
                relocated = self._dynamic_relocations()
                relocated[address] = "__cxa_pure_virtual"
                with offset_patch, symbols_patch, hash_patch, patch.object(
                    native,
                    "_dynamic_relocation_symbols",
                    return_value=relocated,
                ):
                    with self.assertRaisesRegex(
                        HierarchyLinkError,
                        rf"dynamic relocation 0x{address:08x}",
                    ):
                        native.verify_bytes(fixture)


if __name__ == "__main__":
    unittest.main()
