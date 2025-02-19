from __future__ import division
import numpy as np
import skseq.discriminative_sequence_classifier as dsc
import skseq.sequence as seq
import cython
class StructuredPerceptronC(dsc.DiscriminativeSequenceClassifier):
    """
    Implements an Structured  Perceptron
    """

    def __init__(self,
                 observation_labels,
                 state_labels,
                 feature_mapper,
                 learning_rate=1.0,
                 averaged=True):

        dsc.DiscriminativeSequenceClassifier.__init__(self, observation_labels, state_labels, feature_mapper)
        self.learning_rate = learning_rate
        self.averaged = averaged
        self.params_per_epoch = []
        self.parameters = np.zeros(self.feature_mapper.get_num_features())
        self.fitted = False
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def fit(self, dataset, int num_epochs):
        """
        Parameters
        ----------

        dataset:
        Dataset with the sequences and tags

        num_epochs: int
        Number of epochs that the model will be trained


        Returns
        --------

        Nothing. The method only changes self.parameters.
        """
        if self.fitted:
            print("\n\tWarning: Model already trained")

        cdef:
            int epoch
            double acc
        for epoch in range(num_epochs):
            acc = self.fit_epoch(dataset)
            print("Epoch: %i Accuracy: %f" % (epoch, acc))
        if self.averaged:
            new_w = 0
            for old_w in self.params_per_epoch:
                new_w += old_w
            new_w /= len(self.params_per_epoch)
            self.parameters = new_w

        self.fitted = True
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def fit_epoch(self, dataset):
        """
        Method used to train the perceptron for a full epoch over the data

        Parameters
        ----------

        dataset:
        Dataset with the sequences and tags.

        num_epochs: int
        Number of epochs that the model will be trained


        Returns
        --------
        Accuracy for the current epoch.
        """
        cdef:
            int i
            int num_examples = dataset.size()
            int num_labels_total = 0
            int num_mistakes_total = 0
            double acc

        for i in range(num_examples):
            sequence = dataset.seq_list[i]
            num_labels, num_mistakes = self.perceptron_update(sequence)
            num_labels_total += num_labels
            num_mistakes_total += num_mistakes

        self.params_per_epoch.append(self.parameters.copy())
        acc = 1.0 - num_mistakes_total / num_labels_total
        return acc

    def predict_tags_given_words(self, words):
        sequence =  seq.Sequence(x=words, y=words)
        predicted_sequence, _ = self.viterbi_decode(sequence)
        return predicted_sequence.y
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def perceptron_update(self, sequence):
        """
        Method used to train the perceptron for a single datapoint.

        Parameters
        ----------

        sequence:
        datapoint (sequence)


        Returns
        --------
        num_labels: int


        num_mistakes: int

        Accuracy for the current epoch.
        """
        cdef:
            int num_labels = 0
            int num_mistakes = 0
            int y_t_true
            int y_t_hat
            int pos
            int prev_y_t_true
            int prev_y_t_hat
        predicted_sequence, _ = self.viterbi_decode(sequence)

        y_hat = predicted_sequence.y

        # Update initial features.
        y_t_true = sequence.y[0]
        y_t_hat = y_hat[0]

        if y_t_true != y_t_hat:
            true_initial_features = self.feature_mapper.get_initial_features(sequence, y_t_true)
            self.parameters[true_initial_features] += self.learning_rate
            hat_initial_features = self.feature_mapper.get_initial_features(sequence, y_t_hat)
            self.parameters[hat_initial_features] -= self.learning_rate

        for pos in range(len(sequence.x)):
            y_t_true = sequence.y[pos]
            y_t_hat = y_hat[pos]

            # Update emission features.
            num_labels += 1
            if y_t_true != y_t_hat:
                num_mistakes += 1
                true_emission_features = self.feature_mapper.get_emission_features(sequence, pos, y_t_true)
                self.parameters[true_emission_features] += self.learning_rate
                hat_emission_features = self.feature_mapper.get_emission_features(sequence, pos, y_t_hat)
                self.parameters[hat_emission_features] -= self.learning_rate

            if pos > 0:
                # update bigram features
                # If true bigram != predicted bigram update bigram features
                prev_y_t_true = sequence.y[pos-1]
                prev_y_t_hat = y_hat[pos-1]
                if y_t_true != y_t_hat or prev_y_t_true != prev_y_t_hat:
                    true_transition_features = self.feature_mapper.get_transition_features(
                        sequence, pos-1, y_t_true, prev_y_t_true)
                    self.parameters[true_transition_features] += self.learning_rate
                    hat_transition_features = self.feature_mapper.get_transition_features(
                        sequence, pos-1, y_t_hat, prev_y_t_hat)
                    self.parameters[hat_transition_features] -= self.learning_rate

        pos = len(sequence.x)
        y_t_true = sequence.y[pos-1]
        y_t_hat = y_hat[pos-1]

        if y_t_true != y_t_hat:
            true_final_features = self.feature_mapper.get_final_features(sequence, y_t_true)
            self.parameters[true_final_features] += self.learning_rate
            hat_final_features = self.feature_mapper.get_final_features(sequence, y_t_hat)
            self.parameters[hat_final_features] -= self.learning_rate

        return num_labels, num_mistakes

    def save_model(self, dir):
        """
        Saves the parameters of the model
        """
        fn = open(dir + "parameters.txt", 'w')
        for p_id, p in enumerate(self.parameters):
            fn.write("%i\t%f\n" % (p_id, p))
        fn.close()

    def load_model(self, dir):
        """
        Loads the parameters of the model
        """
        fn = open(dir + "parameters.txt", 'r')
        for line in fn:
            toks = line.strip().split("\t")
            p_id = int(toks[0])
            p = float(toks[1])
            self.parameters[p_id] = p
        fn.close()
