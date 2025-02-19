import skseq.sequence as seq
import cython
class _SequenceIterator(object):
    """
    Class used to define how to iterate over a SequenceList object

    Nice explanation: https://anandology.com/python-practice-book/iterators.html
    """
    def __init__(self, seq):
        self.seq = seq
        self.pos = 0

    def __iter__(self):
        return self

    def next(self):
        if self.pos >= len(self.seq):
            raise StopIteration
        r = self.seq[self.pos]
        self.pos += 1
        return r


class SequenceListC(object):

    def __init__(self, x_dict={}, y_dict={}):
        self.x_dict = x_dict
        self.y_dict = y_dict
        self.seq_list = []

    def __str__(self):
        return str(self.seq_list)

    def __repr__(self):
        return repr(self.seq_list)

    def __len__(self):
        return len(self.seq_list)

    def __getitem__(self, ix):
        return self.seq_list[ix]

    def __iter__(self):
        return _SequenceIterator(self)

    def size(self):
        """Returns the number of sequences in the list."""
        return len(self.seq_list)

    def get_num_tokens(self):
        """Returns the number of tokens in the sequence list, that is, the
        sum of the length of the sequences."""
        return sum([seq.size() for seq in self.seq_list])

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def add_sequence(self, x, y, x_dict, y_dict):
        """Add a sequence to the list, where
            - x is the sequence of  observations,
            - y is the sequence of states."""

        # Create and append the sequence

        num_seqs = len(self.seq_list)
        cdef list x_ids = [x_dict.get_label_id(name) for name in x]
        cdef list y_ids = [y_dict.get_label_id(name) for name in y]
        self.seq_list.append(seq.Sequence(x_ids, y_ids))

    def save(self, file):
        seq_fn = open(file, "w")
        for seq in self.seq_list:
            txt = ""
            for pos, word in enumerate(seq.x):
                txt += "%i:%i\t" % (word, seq.y[pos])
            seq_fn.write(txt.strip() + "\n")
        seq_fn.close()

    def load(self, file):
        seq_fn = open(file, "r")
        seq_list = []
        for line in seq_fn:
            seq_x = []
            seq_y = []
            entries = line.strip().split("\t")
            for entry in entries:
                x, y = entry.split(":")
                seq_x.append(int(x))
                seq_y.append(int(y))
            self.add_sequence(seq_x, seq_y)
        seq_fn.close()
































class SequenceUnicodeList(object):

    def __init__(self, tag_dict):
        self.seq_list = []
        self.tag_dict = tag_dict

    def __str__(self):
        return unicode(self.seq_list)

    def __repr__(self):
        return repr(self.seq_list)

    def __len__(self):
        return len(self.seq_list)

    def __getitem__(self, ix):
        return self.seq_list[ix]

    def __iter__(self):
        return _SequenceIterator(self)

    def size(self):
        """Returns the number of sequences in the list."""
        return len(self.seq_list)

    def get_num_tokens(self):
        """Returns the number of tokens in the sequence list, that is, the
        sum of the length of the sequences."""
        return sum([seq.size() for seq in self.seq_list])

    def add_sequence(self, x, y):
        """Add a sequence to the list, where
            - x is the sequence of  observations,
            - y is the sequence of states."""
        num_seqs = len(self.seq_list)
        self.seq_list.append(seq.UnicodeSequence(x, y))

    def save(self, file):
        seq_fn = open(file, "w")
        for seq in self.seq_list:
            txt = ""
            for pos, word in enumerate(seq.x):
                txt += "%i:%i\t" % (word, seq.y[pos])
            seq_fn.write(txt.strip() + "\n")
        seq_fn.close()

    def load(self, file):
        seq_fn = open(file, "r")
        seq_list = []
        for line in seq_fn:
            seq_x = []
            seq_y = []
            entries = line.strip().split("\t")
            for entry in entries:
                x, y = entry.split(":")
                seq_x.append(int(x))
                seq_y.append(int(y))
            self.add_sequence(seq_x, seq_y)
        seq_fn.close()
